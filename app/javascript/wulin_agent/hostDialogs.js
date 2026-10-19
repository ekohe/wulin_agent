// wulin_master pages carry a Materialize confirm modal; anywhere else the
// browser dialog stands in. Cancelling the host modal leaves the promise
// pending, which only means the action never runs.
export function confirmAction(message) {
  const hostConfirm = window.displayCustomizedConfirmModal;
  if (typeof hostConfirm !== "function" || !document.getElementById("confirm-modal")) {
    return Promise.resolve(window.confirm(message));
  }

  return new Promise((resolve) => {
    hostConfirm({message, confirmCallBack: () => resolve(true)});
  });
}
