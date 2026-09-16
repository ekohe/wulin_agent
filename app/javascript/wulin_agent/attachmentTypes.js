export const TEXT_FILE_EXTENSIONS = [
  ".md",
  ".txt",
  ".json",
  ".yaml",
  ".yml",
  ".csv",
  ".tsv",
  ".xml",
  ".html",
  ".htm",
  ".rb",
  ".py",
  ".js",
  ".ts",
  ".jsx",
  ".tsx",
  ".css",
  ".scss",
  ".sql",
  ".log",
  ".ini",
  ".cfg",
  ".conf",
  ".env",
  ".toml",
  ".rst",
  ".adoc",
  ".sh",
  ".bash",
  ".zsh",
  ".php",
  ".go",
  ".rs",
  ".java",
  ".vue",
];

export const ATTACH_ACCEPT = [
  ".zip",
  "application/zip",
  ...TEXT_FILE_EXTENSIONS,
].join(",");

export function attachmentIcon(filename) {
  return filename?.toLowerCase().endsWith(".zip") ? "folder_zip" : "description";
}
