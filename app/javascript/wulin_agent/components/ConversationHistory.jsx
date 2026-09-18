import { useCallback, useEffect, useState } from "react";
import { useAui } from "@assistant-ui/react";
import {
  deleteConversation,
  fetchConversation,
  getConversationId,
  getStoredConversationId,
  listConversations,
  resetConversationId,
  setConversationId,
} from "../api";
import { toAssistantUiMessages } from "../messageMapper";
import { LoadingSpinner } from "./LoadingSpinner";
import { useThreadRunning } from "../useThreadRunning";

const LIST_POLL_MS = 2000;
const CONVERSATION_POLL_MS = 1500;

export function ConversationHistory({
  open,
  width,
  historyVersion,
  onToggle,
  onResizeStart,
  onApprovalModeChange,
  onStatusChange,
}) {
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedId, setSelectedId] = useState(null);
  const aui = useAui();
  const threadRunning = useThreadRunning();

  const rootClass = open
    ? "wulin-agent-history"
    : "wulin-agent-history wulin-agent-history--collapsed";

  const applyConversation = useCallback(
    (data, { syncThread = true } = {}) => {
      setSelectedId(data.id);
      setConversationId(data.id);
      onApprovalModeChange?.(data.approval_mode);
      onStatusChange?.(data.status || "idle");
      if (syncThread) {
        aui.thread().reset(toAssistantUiMessages(data.messages));
      }
    },
    [aui, onApprovalModeChange, onStatusChange]
  );

  useEffect(() => {
    if (historyVersion === 0) setLoading(true);

    listConversations()
      .then(setItems)
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [historyVersion]);

  useEffect(() => {
    if (historyVersion === 0) return;

    const storedId = getStoredConversationId();
    if (storedId) setSelectedId(storedId);
  }, [historyVersion]);

  useEffect(() => {
    const storedId = getStoredConversationId();
    if (!storedId) return;

    fetchConversation(storedId)
      .then((data) => applyConversation(data))
      .catch(() => {
        resetConversationId();
        onStatusChange?.("idle");
      });
  }, [applyConversation, onStatusChange]);

  useEffect(() => {
    if (!threadRunning || !selectedId) return;

    listConversations()
      .then(setItems)
      .catch(console.error);
  }, [threadRunning, selectedId]);

  const hasRunningConversation = items.some((item) => item.status === "running");
  const selectedStatus = items.find(
    (item) => selectedId && String(item.id) === String(selectedId)
  )?.status;

  useEffect(() => {
    if (!hasRunningConversation) return;

    const timer = setInterval(() => {
      listConversations()
        .then(setItems)
        .catch(console.error);
    }, LIST_POLL_MS);

    return () => clearInterval(timer);
  }, [hasRunningConversation]);

  useEffect(() => {
    if (!selectedId) {
      onStatusChange?.("idle");
      return;
    }

    onStatusChange?.(selectedStatus || "idle");

    if (selectedStatus !== "running") return;

    let cancelled = false;
    let timer;

    async function poll() {
      try {
        const data = await fetchConversation(selectedId);
        if (cancelled) return;

        onStatusChange?.(data.status || "idle");
        setItems((prev) =>
          prev.map((item) =>
            String(item.id) === String(selectedId)
              ? { ...item, status: data.status }
              : item
          )
        );

        if (!threadRunning) {
          aui.thread().reset(toAssistantUiMessages(data.messages));
        }

        if (data.status === "running") {
          timer = setTimeout(poll, CONVERSATION_POLL_MS);
        }
      } catch (error) {
        console.error(error);
      }
    }

    poll();

    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
  }, [selectedId, selectedStatus, threadRunning, aui, onStatusChange]);

  async function handleClick(id) {
    const data = await fetchConversation(id);
    applyConversation(data);
  }

  function startNew() {
    resetConversationId();
    setSelectedId(null);
    onStatusChange?.("idle");
    aui.thread().reset([]);
  }

  async function handleDelete(id, event) {
    event.stopPropagation();

    const item = items.find((entry) => String(entry.id) === String(id));
    if (item?.status === "running") return;

    try {
      await deleteConversation(id);
      setItems((prev) => prev.filter((entry) => String(entry.id) !== String(id)));

      if (
        String(getConversationId()) === String(id) ||
        String(selectedId) === String(id)
      ) {
        startNew();
      }
    } catch (error) {
      console.error(error);
    }
  }

  return (
    <div className={rootClass} style={open ? {width} : undefined}>
      <div className="wulin-agent-history__header">
        <button
          type="button"
          className="wulin-agent-history__toggle"
          onClick={onToggle}
          aria-expanded={open}
          aria-label={open ? "Hide history" : "Show history"}
        >
          <i className="material-icons" aria-hidden="true">
            {open ? "chevron_left" : "chevron_right"}
          </i>
        </button>

        {open && !loading && (
          <>
            <span className="wulin-agent-history__title">
              History ({items.length})
            </span>
            <button
              type="button"
              className="wulin-agent-history__new"
              onClick={startNew}
            >
              + New
            </button>
          </>
        )}
      </div>

      {open && loading && (
        <p className="wulin-agent-history__status">Loading…</p>
      )}

      {open && !loading && (
        <ul className="wulin-agent-history__list">
          {items.map((item) => {
            const isActive = String(selectedId) === String(item.id);
            const isRunning = item.status === "running";

            return (
              <li
                key={item.id}
                className={
                  isRunning
                    ? "wulin-agent-history__row wulin-agent-history__row--running"
                    : "wulin-agent-history__row"
                }
              >
                <button
                  type="button"
                  className={
                    isActive
                      ? "wulin-agent-history__item wulin-agent-history__item--active"
                      : "wulin-agent-history__item"
                  }
                  onClick={() => handleClick(item.id)}
                >
                  <span className="wulin-agent-history__item-text">{item.title}</span>
                </button>
                <div className="wulin-agent-history__item-actions">
                  {isRunning ? (
                    <LoadingSpinner
                      className="wulin-agent-history__item-spinner"
                      label="Working in progress"
                    />
                  ) : (
                    <button
                      type="button"
                      className="wulin-agent-history__item-delete"
                      aria-label="Delete conversation"
                      onClick={(event) => handleDelete(item.id, event)}
                    >
                      <i className="material-icons" aria-hidden="true">delete</i>
                    </button>
                  )}
                </div>
              </li>
            );
          })}
        </ul>
      )}

      {open && (
        <div
          className="wulin-agent-history__resize"
          role="separator"
          aria-orientation="vertical"
          aria-label="Resize history"
          onMouseDown={onResizeStart}
        />
      )}
    </div>
  );
}
