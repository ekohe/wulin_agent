import {useRef, useState} from "react";
import {uploadArchive} from "../api";
import {ATTACH_ACCEPT} from "../attachmentTypes";
import {setPendingArchive} from "../pendingArchive";

export function ArchiveUploadButton() {
  const fileInputRef = useRef(null);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState(null);

  const handleClick = () => {
    setError(null);
    fileInputRef.current?.click();
  };

  const handleFileChange = async (event) => {
    const file = event.target.files?.[0];
    event.target.value = "";
    if (!file) return;

    setUploading(true);
    setError(null);

    try {
      const result = await uploadArchive(file);
      setPendingArchive({
        archive_id: result.archive_id,
        filename: file.name,
        file_count: result.file_count,
        inject_mode: result.inject_mode,
        inject_message: result.inject_message,
      });
    } catch (err) {
      setError(err.message || "Upload failed");
    } finally {
      setUploading(false);
    }
  };

  return (
    <>
      <input
        ref={fileInputRef}
        type="file"
        accept={ATTACH_ACCEPT}
        hidden
        onChange={handleFileChange}
      />
      <button
        type="button"
        className="wulin-agent-composer__attach"
        aria-label="Attach a file"
        title="Attach a zip or text file"
        disabled={uploading}
        onClick={handleClick}
      >
        <i className="material-icons" aria-hidden="true">
          attach_file
        </i>
      </button>
      {error && <span className="wulin-agent-composer__attach-error">{error}</span>}
    </>
  );
}
