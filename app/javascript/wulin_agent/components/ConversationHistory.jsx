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
  const [viewedStatus, setViewedStatus] = useState("idle");
  const aui = useAui();
  const threadRunning = useThreadRunning();

  const rootClass = open
    ? "wulin-agent-history"
    : "wulin-agent-history wulin-agent-history--collapsed";

  const syncItemStatus = useCallback((id, status) => {
    setItems((prev) =>
      prev.map((item) =>
        String(item.id) === String(id) ? { ...item, status } : item
      )
    );
  }, []);

  const applyConversation = useCallback(
    (data, { syncThread = true } = {}) => {
      const status = data.status || "idle";

      setSelectedId(data.id);
      setConversationId(data.id);
      setViewedStatus(status);
      onApprovalModeChange?.(data.approval_mode);
      onStatusChange?.(status);
      syncItemStatus(data.id, status);

      if (syncThread) {
        aui.thread().reset(toAssistantUiMessages(data.messages));
      }
    },
    [aui, onApprovalModeChange, onStatusChange, syncItemStatus]
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
        setViewedStatus("idle");
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
      setViewedStatus("idle");
      onStatusChange?.("idle");
      return;
    }

    if (viewedStatus !== "running") return;

    let cancelled = false;
    let timer;

    async function poll() {
      try {
        const data = await fetchConversation(selectedId);
        if (cancelled) return;

        const status = data.status || "idle";
        setViewedStatus(status);
        onStatusChange?.(status);
        syncItemStatus(selectedId, status);

        if (!threadRunning) {
          aui.thread().reset(toAssistantUiMessages(data.messages));
        }

        if (status === "running") {
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
  }, [selectedId, viewedStatus, threadRunning, aui, onStatusChange, syncItemStatus]);

  async function handleClick(id) {
    const data = await fetchConversation(id);
    applyConversation(data);
  }

  function startNew() {
    resetConversationId();
    setSelectedId(null);
    setViewedStatus("idle");
    onStatusChange?.("idle");
    aui.thread().reset([]);
  }

  async function handleDelete(id, event) {
    event.stopPropagation();

    const target = items.find((entry) => String(entry.id) === String(id));
    if (target?.status === "running") return;

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
            const rowClass = [
              "wulin-agent-history__row",
              isActive ? "wulin-agent-history__row--active" : "",
              isRunning ? "wulin-agent-history__row--running" : "",
            ]
              .filter(Boolean)
              .join(" ");

            return (
              <li key={item.id} className={rowClass}>
                <button
                  type="button"
                  className="wulin-agent-history__item"
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
