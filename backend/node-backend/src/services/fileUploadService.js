"use strict";

const fs = require('fs').promises;
const path = require('path');
const { v4: uuidv4 } = require('uuid');
const cloudinaryService = require('./cloudinaryService');

class FileUploadService {
    constructor() {
        this.storageBasePath = process.env.FILE_STORAGE_PATH || 'uploads';
        this.baseUrl = process.env.FILE_BASE_URL || '/uploads';
        
        // Create storage directory if it doesn't exist
        this.ensureStorageDirectory();
    }
    
    async ensureStorageDirectory() {
        try {
            await fs.mkdir(this.storageBasePath, { recursive: true });
        } catch (error) {
            console.error('Failed to create storage directory:', error);
        }
    }
    
    async uploadFile(file, prefix = '', metaOverrides = {}) {
        try {
            await this.ensureStorageDirectory();
            
            const originalName = typeof file.originalname === 'string' ? file.originalname : 'upload.bin';
            const ext = path.extname(originalName);
            const uniqueFilename = `${uuidv4()}${ext}`;

            const metadata = {
                originalName: originalName,
                uploadDate: new Date().toISOString(),
                title: typeof metaOverrides.title === 'string' && metaOverrides.title.trim() !== '' ? metaOverrides.title.trim() : originalName,
                description: typeof metaOverrides.description === 'string' ? metaOverrides.description : '',
                tags: Array.isArray(metaOverrides.tags)
                    ? metaOverrides.tags
                    : (typeof metaOverrides.tags === 'string' && metaOverrides.tags.trim() !== '' ? metaOverrides.tags.split(',').map(s=>s.trim()).filter(Boolean) : []),
                uploadedBy: typeof metaOverrides.uploadedBy === 'string' ? metaOverrides.uploadedBy : undefined,
                uploaderName: typeof metaOverrides.uploaderName === 'string' ? metaOverrides.uploaderName : undefined
            };

            if (cloudinaryService.isConfigured()) {
                const folder = prefix ? `flow/${prefix}` : 'flow/uploads';
                const result = await cloudinaryService.uploadBuffer({
                    buffer: file.buffer,
                    folder,
                    publicId: uniqueFilename.replace(ext, ''),
                    originalFilename: originalName,
                    resourceType: 'auto',
                    tags: metadata.tags,
                });
                return {
                    filename: uniqueFilename,
                    originalName: originalName,
                    title: metadata.title,
                    url: result && (result.secure_url || result.url),
                    size: file.size,
                    uploadedBy: metadata.uploadedBy,
                    uploaderName: metadata.uploaderName,
                    storageProvider: 'cloudinary',
                    cloudinary: {
                        public_id: result && result.public_id,
                        resource_type: result && result.resource_type,
                        version: result && result.version,
                    },
                };
            }
            
            let storagePath;
            let urlPath;
            
            if (prefix) {
                const fullPrefix = path.join(this.storageBasePath, prefix);
                await fs.mkdir(fullPrefix, { recursive: true });
                storagePath = path.join(fullPrefix, uniqueFilename);
                urlPath = `${this.baseUrl}/${prefix}/${uniqueFilename}`;
            } else {
                storagePath = path.join(this.storageBasePath, uniqueFilename);
                urlPath = `${this.baseUrl}/${uniqueFilename}`;
            }

            // Check if file already exists
            try {
                await fs.access(storagePath);
                // If access succeeds, file exists
                throw new Error('File already exists');
            } catch (error) {
                if (error.code !== 'ENOENT') {
                    // If error is not "file not found", rethrow it (e.g. "File already exists" or permission error)
                    throw error;
                }
                // File does not exist, proceed
            }
            
            // Write file to storage
            await fs.writeFile(storagePath, file.buffer);
            try {
                await fs.writeFile(`${storagePath}.meta.json`, JSON.stringify(metadata));
            } catch (error) {}
            
            return {
                filename: uniqueFilename,
                originalName: originalName,
                title: metadata.title,
                url: urlPath,
                size: file.size,
                uploadedBy: metadata.uploadedBy,
                uploaderName: metadata.uploaderName,
                storageProvider: 'local'
            };
            
        } catch (error) {
            console.error('File upload failed:', error);
            throw new Error(`File upload failed: ${error.message}`);
        }
    }
    
    getPresignedUrl(filename, expiresIn = 3600) {
        // For local storage, we just return the direct URL
        // In production, this would generate a signed URL for cloud storage
        return `${this.baseUrl}/${filename}`;
    }
    
    async deleteFile(filename, prefix = '') {
        try {
            if (prefix) {
                const fullPath = path.join(this.storageBasePath, prefix, filename);
                try {
                    await fs.access(fullPath);
                    await fs.unlink(fullPath);
                    try { await fs.unlink(`${fullPath}.meta.json`); } catch (_) {}
                    return true;
                } catch (error) {
                    if (error.code === 'ENOENT') return false;
                    throw error;
                }
            }

            // Try direct path first
            const directPath = path.join(this.storageBasePath, filename);
            const candidates = [directPath];
            // Also check one-level subdirectories for the file
            try {
                const entries = await fs.readdir(this.storageBasePath, { withFileTypes: true });
                for (const entry of entries) {
                    if (entry.isDirectory()) {
                        candidates.push(path.join(this.storageBasePath, entry.name, filename));
                    }
                }
            } catch (_) {}

            for (const p of candidates) {
                try {
                    await fs.access(p);
                    await fs.unlink(p);
                    // Delete sidecar metadata if present
                    try { await fs.unlink(`${p}.meta.json`); } catch (_) {}
                    return true;
                } catch (error) {
                    if (error.code === 'ENOENT') {
                        continue;
                    }
                }
            }
            return false;
        } catch (error) {
            console.error('File deletion failed:', error);
            return false;
        }
    }

    async listFiles(prefix = '') {
        try {
            const directoryPath = prefix ? path.join(this.storageBasePath, prefix) : this.storageBasePath;
            
            // Check if directory exists
            try {
                await fs.access(directoryPath);
            } catch (error) {
                if (error.code === 'ENOENT') {
                    return []; // Directory doesn't exist, return empty list
                }
                throw error;
            }
            
            const fileDetails = [];

            const walk = async (dirPath, relPrefix) => {
                const entries = await fs.readdir(dirPath, { withFileTypes: true });
                for (const entry of entries) {
                    const entryPath = path.join(dirPath, entry.name);
                    if (entry.isDirectory()) {
                        const nextRel = relPrefix ? path.posix.join(relPrefix, entry.name) : entry.name;
                        await walk(entryPath, nextRel);
                        continue;
                    }
                    if (!entry.isFile()) continue;
                    if (entry.name.endsWith('.meta.json')) continue;

                    try {
                        const stats = await fs.stat(entryPath);
                        let originalName = entry.name;
                        let title = undefined;
                        let description = '';
                        let tags = [];
                        let uploadDate = stats.mtime;
                        let uploadedBy = undefined;
                        let uploaderName = undefined;
                        try {
                            const metaRaw = await fs.readFile(`${entryPath}.meta.json`, 'utf8');
                            const meta = JSON.parse(metaRaw);
                            if (meta && meta.originalName) originalName = meta.originalName;
                            if (meta && meta.title) title = meta.title;
                            if (meta && meta.description) description = meta.description;
                            if (meta && meta.tags) tags = meta.tags;
                            if (meta && meta.uploadDate) uploadDate = new Date(meta.uploadDate);
                            if (meta && meta.uploadedBy) uploadedBy = meta.uploadedBy;
                            if (meta && meta.uploaderName) uploaderName = meta.uploaderName;
                        } catch (_) {}

                        const relFile = relPrefix ? path.posix.join(relPrefix, entry.name) : entry.name;
                        fileDetails.push({
                            filename: entry.name,
                            originalName: originalName,
                            title: title,
                            description: description,
                            tags: tags,
                            size: stats.size,
                            uploadDate: uploadDate,
                            url: `${this.baseUrl}/${relFile}`,
                            uploadedBy: uploadedBy,
                            uploaderName: uploaderName,
                            storageProvider: 'local'
                        });
                    } catch (error) {
                        console.error(`Error getting details for file ${entry.name}:`, error);
                    }
                }
            };

            const relRoot = prefix ? prefix.split(path.sep).join(path.posix.sep) : '';
            await walk(directoryPath, relRoot);
            
            return fileDetails;
            
        } catch (error) {
            console.error('File listing failed:', error);
            throw new Error(`File listing failed: ${error.message}`);
        }
    }
}

// Create global instance
const fileUploadService = new FileUploadService();

module.exports = fileUploadService;
