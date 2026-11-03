import {useEffect, useId, useRef} from "react";
import {strings} from "../strings";

// Confirms a destructive action. A native modal dialog sits in the browser's
// top layer, above the drawer, its backdrop and any host modal, on every page
// the panel renders on. It keeps focus inside until it closes, and Escape
// cancels it.
export function ConfirmDialog({message, confirmLabel, onConfirm, onCancel}) {
  const dialog = useRef(null);
  const cancelButton = useRef(null);
  const messageId = useId();

  useEffect(() => {
    const element = dialog.current;
    const opener = document.activeElement;
    element.showModal();
    // The safe choice takes focus, so Enter alone never confirms.
    cancelButton.current.focus();

    return () => {
      if (element.open) element.close();
      if (opener instanceof HTMLElement && opener.isConnected) opener.focus();
    };
  }, []);

  return (
    <dialog
      ref={dialog}
      className="wulin-agent-confirm"
      role="alertdialog"
      aria-labelledby={messageId}
      onCancel={(event) => {
        event.preventDefault();
        onCancel();
      }}
    >
      <p id={messageId} className="wulin-agent-confirm__message">{message}</p>
      <div className="wulin-agent-confirm__actions">
        <button ref={cancelButton} type="button" className="wulin-agent-confirm__cancel" onClick={onCancel}>
          {strings.cancel}
        </button>
        <button type="button" className="wulin-agent-confirm__confirm" onClick={onConfirm}>
          {confirmLabel}
        </button>
      </div>
    </dialog>
  );
}
