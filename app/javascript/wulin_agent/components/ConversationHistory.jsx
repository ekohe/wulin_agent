import { useCallback, useEffect, useRef, useState } from "react";
import { useAui, useAuiState } from "@assistant-ui/react";
import {
  deleteConversation,
  fetchConversation,
  getConversationId,
  getStoredConversationId,
  listConversations,
  resetConversationId,
  setConversationId,
} from "../api";
import {
  hasPendingApproval,
  hasPendingApprovalInApi,
  toAssistantUiMessages,
} from "../messageMapper";
import {IconButton} from "./IconButton";
import {StatusMark} from "./StatusMark";
import { useThreadRunning } from "../useThreadRunning";
import {strings} from "../strings";
import {ConfirmDialog} from "./ConfirmDialog";

const LIST_POLL_MS = 2000;
const CONVERSATION_POLL_MS = 1500;

function resolveStatus(serverStatus, {threadRunning, conversationId, selectedId}) {
  const status = serverStatus || "idle";
  if (
    status === "idle" &&
    threadRunning &&
    selectedId &&
    String(conversationId) === String(selectedId)
  ) {
    return "running";
  }
  return status;
}

function withLocalRunning(items, {threadRunning, selectedId}) {
  if (!threadRunning || !selectedId) return items;

  return items.map((item) =>
    String(item.id) === String(selectedId) ? {...item, status: "running"} : item
  );
}

export function ConversationHistory({
  open,
  width,
  historyVersion,
  onToggle,
  onResizeStart,
  onApprovalModeChange,
  onStatusChange,
  onAwaitingApprovalChange,
}) {
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [notice, setNotice] = useState("");
  const clearNotice = (message) =>
    setNotice((current) => (current === message ? "" : current));
  const [selectedId, setSelectedId] = useState(null);
  const [viewedStatus, setViewedStatus] = useState("idle");
  const [pendingDeleteId, setPendingDeleteId] = useState(null);
  const newButtonRef = useRef(null);
  const aui = useAui();
  const threadRunning = useThreadRunning();
  const threadRunningRef = useRef(threadRunning);
  threadRunningRef.current = threadRunning;
  const threadPendingApproval = useAuiState((state) =>
    hasPendingApproval(state.thread.messages)
  );
  const threadPendingRef = useRef(threadPendingApproval);
  threadPendingRef.current = threadPendingApproval;

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
    (data, { syncThread = true, force = false } = {}) => {
      const status = resolveStatus(data.status, {
        threadRunning: threadRunningRef.current,
        conversationId: data.id,
        selectedId: data.id,
      });

      setSelectedId(data.id);
      setConversationId(data.id);
      setViewedStatus(status);
      onApprovalModeChange?.(data.approval_mode);
      onStatusChange?.(status);
      onAwaitingApprovalChange?.(hasPendingApprovalInApi(data.messages));
      syncItemStatus(data.id, status);

      if (syncThread && (force || !threadRunningRef.current)) {
        aui.thread().reset(toAssistantUiMessages(data.messages));
      }
    },
    [aui, onApprovalModeChange, onAwaitingApprovalChange, onStatusChange, syncItemStatus]
  );

  const loadListItems = useCallback(async () => {
    const nextItems = await listConversations();
    setItems(withLocalRunning(nextItems, {threadRunning, selectedId}));
    clearNotice(strings.historyLoadFailed);
  }, [threadRunning, selectedId]);

  useEffect(() => {
    if (historyVersion === 0) setLoading(true);

    listConversations()
      .then((nextItems) => {
        setItems(nextItems);
        setNotice("");
      })
      .catch((error) => {
        console.error(error);
        setNotice(strings.historyLoadFailed);
      })
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
      .catch((error) => {
        console.error(error);
        if (error?.status === 404) {
          resetConversationId();
          setViewedStatus("idle");
          onStatusChange?.("idle");
          onAwaitingApprovalChange?.(false);
          return;
        }
        setNotice(strings.historyOpenFailed);
      });
  }, [applyConversation, onStatusChange]);

  useEffect(() => {
    if (!threadRunning || !selectedId) return;

    onAwaitingApprovalChange?.(false);
    setViewedStatus("running");
    onStatusChange?.("running");
    syncItemStatus(selectedId, "running");
  }, [threadRunning, selectedId, onAwaitingApprovalChange, onStatusChange, syncItemStatus]);

  const hasRunningConversation =
    items.some((item) => item.status === "running") ||
    Boolean(threadRunning && selectedId);

  useEffect(() => {
    if (!hasRunningConversation) return;

    const timer = setInterval(() => {
      loadListItems().catch((error) => {
        console.error(error);
        setNotice(strings.historyLoadFailed);
      });
    }, LIST_POLL_MS);

    return () => clearInterval(timer);
  }, [hasRunningConversation, loadListItems]);

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

        const status = resolveStatus(data.status, {
          threadRunning: threadRunningRef.current,
          conversationId: selectedId,
          selectedId,
        });
        setViewedStatus(status);
        onStatusChange?.(status);
        onAwaitingApprovalChange?.(hasPendingApprovalInApi(data.messages));
        syncItemStatus(selectedId, status);
        clearNotice(strings.historyOpenFailed);

        if (!threadRunningRef.current) {
          const mapped = toAssistantUiMessages(data.messages);
          const skipReset =
            threadPendingRef.current && !hasPendingApprovalInApi(data.messages);

          if (!skipReset) {
            aui.thread().reset(mapped);
          }
        }

        if (status === "running") {
          timer = setTimeout(poll, CONVERSATION_POLL_MS);
        }
      } catch (error) {
        console.error(error);
        setNotice(strings.historyOpenFailed);
      }
    }

    poll();

    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
  }, [selectedId, viewedStatus, threadRunning, aui, onAwaitingApprovalChange, onStatusChange, syncItemStatus]);

  async function handleClick(id) {
    try {
      const data = await fetchConversation(id);
      applyConversation(data, {force: true});
      setNotice("");
    } catch (error) {
      console.error(error);
      setNotice(strings.historyOpenFailed);
    }
  }

  function startNew() {
    resetConversationId();
    setSelectedId(null);
    setViewedStatus("idle");
    onStatusChange?.("idle");
    onAwaitingApprovalChange?.(false);
    aui.thread().reset([]);
  }

  function isRunningItem(id) {
    const target = items.find((entry) => String(entry.id) === String(id));
    return target?.status === "running";
  }

  function requestDelete(id, event) {
    event.stopPropagation();
    if (isRunningItem(id)) return;
    setPendingDeleteId(id);
  }

  async function confirmDelete() {
    const id = pendingDeleteId;
    setPendingDeleteId(null);
    // The list polls while the dialog is open; a run may have started since.
    if (isRunningItem(id)) return;

    try {
      await deleteConversation(id);
      setItems((prev) => prev.filter((entry) => String(entry.id) !== String(id)));

      if (
        String(getConversationId()) === String(id) ||
        String(selectedId) === String(id)
      ) {
        startNew();
      }
      // The row and its delete button are gone; keep focus in the history.
      newButtonRef.current?.focus();
    } catch (error) {
      console.error(error);
      setNotice(strings.historyDeleteFailed);
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
          aria-label={open ? strings.hideHistory : strings.showHistory}
        >
          <span className="material-icons" aria-hidden="true">
            {open ? "chevron_left" : "chevron_right"}
          </span>
        </button>

        {open && !loading && (
          <>
            <span className="wulin-agent-history__title">
              {strings.historyTitle(items.length)}
            </span>
            <button
              ref={newButtonRef}
              type="button"
              className="wulin-agent-history__new"
              onClick={startNew}
            >
              {strings.newConversation}
            </button>
          </>
        )}
      </div>

      {open && notice && (
        <p className="wulin-agent-history__notice" role="alert">{notice}</p>
      )}

      {open && loading && (
        <p className="wulin-agent-history__status">{strings.loading}</p>
      )}

      {open && !loading && (
        <ul className="wulin-agent-history__list">
          {items.map((item) => {
            const isActive = String(selectedId) === String(item.id);
            const isRunning =
              item.status === "running" || (isActive && threadRunning);
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
                  onClick={(event) => {
                    event.currentTarget.blur();
                    handleClick(item.id);
                  }}
                >
                  <span className="wulin-agent-history__item-text">{item.title}</span>
                  {isRunning && <StatusMark status="running" />}
                </button>
                {!isRunning && (
                  <div className="wulin-agent-history__item-actions">
                    <IconButton
                      icon="delete"
                      label={strings.deleteConversationLabel}
                      className="wulin-agent-history__item-delete"
                      onClick={(event) => requestDelete(item.id, event)}
                    />
                  </div>
                )}
              </li>
            );
          })}
        </ul>
      )}

      {pendingDeleteId !== null && (
        <ConfirmDialog
          message={strings.deleteConversation}
          confirmLabel={strings.delete}
          onConfirm={confirmDelete}
          onCancel={() => setPendingDeleteId(null)}
        />
      )}

      {open && (
        <div
          className="wulin-agent-history__resize"
          role="separator"
          aria-orientation="vertical"
          aria-label={strings.resizeHistory}
          onMouseDown={onResizeStart}
        />
      )}
    </div>
  );
}
