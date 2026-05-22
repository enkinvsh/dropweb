package app.dropweb

import android.database.Cursor
import android.database.MatrixCursor
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import android.provider.DocumentsContract.Document
import android.provider.DocumentsContract.Root
import android.provider.DocumentsProvider
import java.io.File
import java.io.FileNotFoundException


/**
 * Storage Access Framework root that exposes ONLY the app-owned `configs/`
 * and `logs/` directories under [android.content.Context.getFilesDir]. The
 * provider is declared with `MANAGE_DOCUMENTS` so only the system documents
 * UI can bind to it, but the surface is still hardened on top of that:
 *
 *   - Document IDs are opaque relative paths rooted at `filesDir`; the
 *     synthetic root id is [ROOT_DOCUMENT_ID]. Absolute paths and `..`
 *     traversal sequences are rejected outright.
 *   - Every caller-supplied id is canonicalised and verified to live inside
 *     one of the [ALLOWED_SUBDIRS] roots before any filesystem call. This
 *     blocks symlink-based escape attempts that would otherwise resolve
 *     outside the app sandbox.
 *   - The surface is read-only: no `FLAG_SUPPORTS_WRITE`/`FLAG_SUPPORTS_DELETE`
 *     is advertised, and [openDocument] refuses any mode other than `"r"`.
 *
 * Phase 2 Google Play readiness — limits the SAF sharing surface to the
 * minimum needed for users to view exported configs and logs through the
 * system documents UI.
 */
class FilesProvider : DocumentsProvider() {

    companion object {
        private const val DEFAULT_ROOT_ID = "0"

        /** Synthetic, opaque root document id. Not a filesystem path. */
        private const val ROOT_DOCUMENT_ID = "root"

        /**
         * Subdirectories of `Context.filesDir` that the SAF surface is
         * allowed to expose. Kept in sync with `res/xml/file_paths.xml`
         * intentionally — the AndroidX `FileProvider` shares the same
         * narrow set so the two providers do not drift apart.
         */
        private val ALLOWED_SUBDIRS = arrayOf("configs", "logs")

        private val DEFAULT_DOCUMENT_COLUMNS = arrayOf(
            Document.COLUMN_DOCUMENT_ID,
            Document.COLUMN_DISPLAY_NAME,
            Document.COLUMN_MIME_TYPE,
            Document.COLUMN_FLAGS,
            Document.COLUMN_SIZE,
        )
        private val DEFAULT_ROOT_COLUMNS = arrayOf(
            Root.COLUMN_ROOT_ID,
            Root.COLUMN_FLAGS,
            Root.COLUMN_ICON,
            Root.COLUMN_TITLE,
            Root.COLUMN_SUMMARY,
            Root.COLUMN_DOCUMENT_ID
        )
    }

    override fun onCreate(): Boolean {
        return true
    }

    override fun queryRoots(projection: Array<String>?): Cursor {
        return MatrixCursor(projection ?: DEFAULT_ROOT_COLUMNS).apply {
            newRow().apply {
                add(Root.COLUMN_ROOT_ID, DEFAULT_ROOT_ID)
                add(Root.COLUMN_FLAGS, Root.FLAG_LOCAL_ONLY)
                add(Root.COLUMN_ICON, R.mipmap.ic_launcher)
                add(Root.COLUMN_TITLE, context!!.getString(R.string.app_name))
                add(Root.COLUMN_SUMMARY, "Data")
                add(Root.COLUMN_DOCUMENT_ID, ROOT_DOCUMENT_ID)
            }
        }
    }

    override fun queryChildDocuments(
        parentDocumentId: String,
        projection: Array<String>?,
        sortOrder: String?
    ): Cursor {
        val result = MatrixCursor(resolveDocumentProjection(projection))
        if (parentDocumentId == ROOT_DOCUMENT_ID) {
            for (subdir in ALLOWED_SUBDIRS) {
                val file = resolveFile(subdir) ?: continue
                if (file.exists() && file.isDirectory) {
                    includeFile(result, subdir, file)
                }
            }
            return result
        }
        val parentFile = resolveFile(parentDocumentId)
            ?: throw FileNotFoundException("Document not found: $parentDocumentId")
        if (!parentFile.isDirectory) {
            throw FileNotFoundException("Not a directory: $parentDocumentId")
        }
        val children = parentFile.listFiles() ?: return result
        for (child in children) {
            val childId = "$parentDocumentId/${child.name}"
            // Re-resolve via the opaque id so symlink-escapes are rejected
            // even if listFiles() returned a path that walks outside the
            // allowed roots.
            val safe = resolveFile(childId) ?: continue
            includeFile(result, childId, safe)
        }
        return result
    }

    override fun queryDocument(documentId: String, projection: Array<String>?): Cursor {
        val result = MatrixCursor(resolveDocumentProjection(projection))
        if (documentId == ROOT_DOCUMENT_ID) {
            result.newRow().apply {
                add(Document.COLUMN_DOCUMENT_ID, ROOT_DOCUMENT_ID)
                add(Document.COLUMN_DISPLAY_NAME, context!!.getString(R.string.app_name))
                add(Document.COLUMN_SIZE, 0L)
                add(Document.COLUMN_FLAGS, 0)
                add(Document.COLUMN_MIME_TYPE, Document.MIME_TYPE_DIR)
            }
            return result
        }
        val file = resolveFile(documentId)
            ?: throw FileNotFoundException("Document not found: $documentId")
        includeFile(result, documentId, file)
        return result
    }

    override fun openDocument(
        documentId: String,
        mode: String,
        signal: CancellationSignal?
    ): ParcelFileDescriptor {
        // Read-only surface: refuse any write/append/truncate request.
        // We never advertise FLAG_SUPPORTS_WRITE / FLAG_SUPPORTS_DELETE, so
        // a non-"r" mode here is a misuse and we reject it instead of
        // silently opening for write.
        if (mode != "r") {
            throw FileNotFoundException("Read-only document: $documentId")
        }
        val file = resolveFile(documentId)
            ?: throw FileNotFoundException("Document not found: $documentId")
        if (!file.isFile) {
            throw FileNotFoundException("Not a file: $documentId")
        }
        return ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
    }

    /**
     * Resolve an opaque relative document id into the corresponding [File]
     * under one of the allowed roots, or return `null` when the id is
     * outside the allowed-roots set, contains traversal sequences, points
     * at an absolute external path, or otherwise escapes (e.g. through
     * symlinks) the app's private storage.
     */
    private fun resolveFile(documentId: String): File? {
        val ctx = context ?: return null
        if (documentId.isEmpty() || documentId == ROOT_DOCUMENT_ID) return null
        // Reject absolute paths and `..` traversal up-front; the canonical
        // check below catches symlink-based escapes that survive these.
        if (documentId.startsWith('/') || documentId.contains("..")) return null

        val filesDir = try {
            ctx.filesDir.canonicalFile
        } catch (_: Throwable) {
            return null
        }
        val candidate = try {
            File(filesDir, documentId).canonicalFile
        } catch (_: Throwable) {
            return null
        }
        val candidatePath = candidate.path
        for (subdir in ALLOWED_SUBDIRS) {
            val root = try {
                File(filesDir, subdir).canonicalFile
            } catch (_: Throwable) {
                continue
            }
            if (candidatePath == root.path ||
                candidatePath.startsWith(root.path + File.separator)
            ) {
                return candidate
            }
        }
        return null
    }

    private fun includeFile(result: MatrixCursor, documentId: String, file: File) {
        result.newRow().apply {
            add(Document.COLUMN_DOCUMENT_ID, documentId)
            add(Document.COLUMN_DISPLAY_NAME, file.name)
            add(Document.COLUMN_SIZE, if (file.isFile) file.length() else 0L)
            // Read-only: deliberately no FLAG_SUPPORTS_WRITE / FLAG_SUPPORTS_DELETE.
            add(Document.COLUMN_FLAGS, 0)
            add(Document.COLUMN_MIME_TYPE, getDocumentType(file))
        }
    }

    private fun getDocumentType(file: File): String {
        return if (file.isDirectory) {
            Document.MIME_TYPE_DIR
        } else {
            "application/octet-stream"
        }
    }

    private fun resolveDocumentProjection(projection: Array<String>?): Array<String> {
        return projection ?: DEFAULT_DOCUMENT_COLUMNS
    }
}
