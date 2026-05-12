"use strict";

const express = require('express');
const multer = require('multer');
const path = require('path');
const fileUploadService = require('../services/fileUploadService');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

// Configure multer for file uploads
const upload = multer({
    storage: multer.memoryStorage(),
    limits: {
        fileSize: 10 * 1024 * 1024, // 10MB limit
    },
    fileFilter: (req, file, cb) => {
        // Repository uploads must accept any document/file type. Preview/open
        // handling is decided later by the client based on file extension.
        cb(null, true);
    }
});

const handleMulterSingle = (req, res, next) => {
    upload.single('file')(req, res, (err) => {
        if (err) {
            return res.status(400).json({ error: err.message });
        }
        next();
    });
};

const handleMulterArray = (req, res, next) => {
    upload.array('files')(req, res, (err) => {
        if (err) {
            return res.status(400).json({ error: err.message });
        }
        next();
    });
};

// Upload single file
router.post('/upload', authenticateToken, handleMulterSingle, async (req, res) => {
    try {
        let { prefix = '' } = req.body;
        const { project_id, project_key, sprint_id, deliverable_id } = req.body || {};
        const derivedTags = [];
        if (project_id) derivedTags.push(`project:${project_id}`);
        if (project_key) derivedTags.push(`projectKey:${project_key}`);
        if (sprint_id) {
            derivedTags.push(`sprint:${sprint_id}`);
            if (!prefix) prefix = `sprints/${sprint_id}`;
        }
        if (deliverable_id) {
            derivedTags.push(`deliverable:${deliverable_id}`);
            if (!prefix) prefix = `deliverables/${deliverable_id}`;
        }
        
        if (!req.file) {
            return res.status(400).json({ 
                error: 'No file provided' 
            });
        }
        
        const uploadResult = await fileUploadService.uploadFile(
            req.file,
            prefix,
            {
                title: req.body && req.body.title,
                description: req.body && req.body.description,
                tags: (req.body && req.body.tags) ? req.body.tags : derivedTags,
                uploadedBy: (req.user && req.user.id) || undefined,
                uploaderName: (req.user && (req.user.name || req.user.email)) || undefined
            }
        );
        try {
            if (global && global.realtimeEvents) {
                const ext = String(path.extname(uploadResult.filename || uploadResult.originalName || '')).replace('.', '').toLowerCase();
                const sizeInMB = Math.round(((uploadResult.size || 0) / (1024 * 1024)) * 100) / 100;
                const repoDoc = {
                    id: uploadResult.filename,
                    name: uploadResult.title || uploadResult.originalName || uploadResult.filename,
                    fileType: ext || 'file',
                    uploaded_at: new Date().toISOString(),
                    uploaded_by: (req.user && req.user.id) || 'system',
                    size: uploadResult.size,
                    size_in_mb: sizeInMB,
                    description: (req.body && req.body.description) || '',
                    tags: (req.body && req.body.tags) || '',
                    file_path: uploadResult.url,
                    uploader_name: (req.user && (req.user.name || req.user.email)) || 'System',
                };
                global.realtimeEvents.emit('document_uploaded', repoDoc);
            }
        } catch (_) {}
        res.status(200).json(uploadResult);
        
    } catch (error) {
        console.error('File upload error:', error);
        res.status(500).json({ 
            error: 'File upload failed', 
            details: error.message 
        });
    }
});

// Upload multiple files
router.post('/upload-multiple', authenticateToken, handleMulterArray, async (req, res) => {
    try {
        const { prefix = '' } = req.body;
        
        if (!req.files || req.files.length === 0) {
            return res.status(400).json({ 
                error: 'No files provided' 
            });
        }
        
        const results = [];
        
        for (const file of req.files) {
            try {
                const uploadResult = await fileUploadService.uploadFile(file, prefix);
                results.push({
                    ...uploadResult,
                    success: true
                });
            } catch (error) {
                results.push({
                    filename: file.originalname,
                    error: error.message,
                    success: false
                });
            }
        }
        
        res.status(200).json(results);
        
    } catch (error) {
        console.error('Multiple file upload error:', error);
        res.status(500).json({ 
            error: 'Multiple file upload failed', 
            details: error.message 
        });
    }
});

// Get presigned URL for file access
router.get('/presigned-url/:filename', authenticateToken, async (req, res) => {
    try {
        const { filename } = req.params;
        const { expires_in = 3600 } = req.query;
        
        const expiresIn = parseInt(expires_in);
        
        const presignedUrl = fileUploadService.getPresignedUrl(filename, expiresIn);
        
        if (!presignedUrl) {
            return res.status(404).json({ 
                error: 'File not found or presigned URL generation failed' 
            });
        }
        
        const expiresAt = new Date(Date.now() + expiresIn * 1000);
        
        res.status(200).json({
            filename,
            presigned_url: presignedUrl,
            expires_at: expiresAt.toISOString()
        });
        
    } catch (error) {
        console.error('Presigned URL error:', error);
        res.status(500).json({ 
            error: 'Failed to generate presigned URL', 
            details: error.message 
        });
    }
});

// List files
router.get('/', authenticateToken, async (req, res) => {
    try {
        const { prefix = '' } = req.query;
        
        const files = await fileUploadService.listFiles(prefix);
        
        res.status(200).json(files);
        
    } catch (error) {
        console.error('File listing error:', error);
        res.status(500).json({ 
            error: 'Failed to list files', 
            details: error.message 
        });
    }
});

// Delete file
router.delete('/:filename', authenticateToken, async (req, res) => {
    try {
        const { filename } = req.params;
        
        const success = await fileUploadService.deleteFile(filename);
        
        if (!success) {
            return res.status(404).json({ 
                error: 'File not found or deletion failed' 
            });
        }
        
        res.status(200).json({ 
            message: 'File deleted successfully', 
            filename 
        });
        
    } catch (error) {
        console.error('File deletion error:', error);
        res.status(500).json({ 
            error: 'File deletion failed', 
            details: error.message 
        });
    }
});

module.exports = router;
