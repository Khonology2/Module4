const express = require('express');
const router = express.Router();
const path = require('path');
const fs = require('fs');
const axios = require('axios');
const { authenticateToken } = require('../middleware/auth');
const { RepositoryDocument } = require('../models');
const { Op } = require('sequelize');
const fileUploadService = require('../services/fileUploadService');
const cloudinaryService = require('../services/cloudinaryService');

function toRepositoryFile(record) {
  const ext = path.extname(record.filename || '').replace('.', '').toLowerCase();
  const size = Number(record.file_size || 0) || 0;
  const sizeInMB = Math.round((size / (1024 * 1024)) * 100) / 100;
  return {
    id: record.filename,
    name: record.title || record.original_name || record.filename,
    fileType: ext || 'file',
    uploaded_at: new Date(record.created_at || Date.now()).toISOString(),
    uploaded_by: record.uploaded_by || 'system',
    size: size,
    size_in_mb: sizeInMB,
    description: record.description || '',
    tags: record.tags || '',
    file_path: record.url,
    uploader_name: record.uploader_name || 'System',
  };
}

router.get('/', authenticateToken, async (req, res) => {
  try {
    const { search, fileType } = req.query;
    const project_id = req.query.project_id ?? req.query.projectId;
    const project_key = req.query.project_key ?? req.query.projectKey;
    const sprint_id = req.query.sprint_id ?? req.query.sprintId;
    const deliverable_id = req.query.deliverable_id ?? req.query.deliverableId;

    const dialect = (RepositoryDocument && RepositoryDocument.sequelize && RepositoryDocument.sequelize.getDialect)
      ? RepositoryDocument.sequelize.getDialect()
      : '';
    const likeOp = String(dialect).toLowerCase() === 'postgres' ? Op.iLike : Op.like;

    const where = {};
    if (project_id) where.project_id = String(project_id);
    if (project_key) where.project_key = String(project_key);
    if (sprint_id) where.sprint_id = parseInt(String(sprint_id), 10);
    if (deliverable_id) where.deliverable_id = parseInt(String(deliverable_id), 10);

    const and = [];
    const s = typeof search === 'string' ? search.trim() : '';
    if (s) {
      and.push({
        [Op.or]: [
          { title: { [likeOp]: `%${s}%` } },
          { original_name: { [likeOp]: `%${s}%` } },
          { description: { [likeOp]: `%${s}%` } },
          { tags: { [likeOp]: `%${s}%` } },
          { filename: { [likeOp]: `%${s}%` } },
        ],
      });
    }

    const ft = typeof fileType === 'string' ? fileType.trim().toLowerCase() : '';
    if (ft) {
      and.push({ filename: { [likeOp]: `%.${ft}` } });
    }

    const finalWhere = and.length > 0 ? { ...where, [Op.and]: and } : where;
    const rows = await RepositoryDocument.findAll({
      where: finalWhere,
      order: [['created_at', 'DESC']],
      limit: 1000,
    });

    res.json({ success: true, data: rows.map(toRepositoryFile) });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message || 'Failed to list documents' });
  }
});

// Upload not implemented here; use /api/v1/files/upload instead

router.get('/:id', authenticateToken, async (req, res) => {
  try {
    const record = await RepositoryDocument.findOne({ where: { filename: req.params.id } });
    if (!record) return res.status(404).json({ success: false, error: 'Document not found' });
    res.json({ success: true, data: toRepositoryFile(record) });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message || 'Failed to get document' });
  }
});

router.get('/:id/content', authenticateToken, async (req, res) => {
  try {
    const record = await RepositoryDocument.findOne({ where: { filename: req.params.id } });
    if (!record) return res.status(404).json({ success: false, error: 'Document not found' });

    if (String(record.storage_provider || '').toLowerCase() === 'cloudinary' && record.url) {
      try {
        const r = await axios.get(String(record.url), { responseType: 'arraybuffer', timeout: 15000 });
        const originalName = record.title || record.original_name || record.filename;
        const ext = path.extname(String(originalName)).replace('.', '').toLowerCase();
        let contentType = r.headers && r.headers['content-type'] ? String(r.headers['content-type']) : 'application/octet-stream';
        if (!contentType || contentType.trim() === '') contentType = 'application/octet-stream';
        if (ext === 'pdf') contentType = 'application/pdf';
        res.setHeader('Content-Disposition', `inline; filename="${String(originalName).replace(/"/g, '')}"`);
        res.setHeader('Content-Type', contentType);
        return res.send(Buffer.from(r.data));
      } catch (e) {
        return res.status(404).json({ success: false, error: 'File not found' });
      }
    }

    const rel = String(record.url || '').replace(fileUploadService.baseUrl, '').replace(/^\//, '');
    const filePath = path.resolve(fileUploadService.storageBasePath, rel || record.filename);
    if (!fs.existsSync(filePath)) return res.status(404).json({ success: false, error: 'File not found' });
    const originalName = record.title || record.original_name || record.filename;
    const ext = path.extname(String(originalName)).replace('.', '').toLowerCase();
    let contentType = 'application/octet-stream';
    if (ext === 'pdf') contentType = 'application/pdf';
    else if (ext === 'txt' || ext === 'md' || ext === 'log') contentType = 'text/plain';
    else if (ext === 'json') contentType = 'application/json';
    else if (ext === 'xml') contentType = 'application/xml';
    else if (ext === 'csv') contentType = 'text/csv';
    else if (ext === 'jpg' || ext === 'jpeg') contentType = 'image/jpeg';
    else if (ext === 'png') contentType = 'image/png';
    else if (ext === 'gif') contentType = 'image/gif';
    else if (ext === 'webp') contentType = 'image/webp';
    else if (ext === 'bmp') contentType = 'image/bmp';
    else if (ext === 'mp4') contentType = 'video/mp4';
    else if (ext === 'webm') contentType = 'video/webm';
    else if (ext === 'mp3') contentType = 'audio/mpeg';
    else if (ext === 'wav') contentType = 'audio/wav';
    else if (ext === 'doc') contentType = 'application/msword';
    else if (ext === 'docx') contentType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    else if (ext === 'xls') contentType = 'application/vnd.ms-excel';
    else if (ext === 'xlsx') contentType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    else if (ext === 'ppt') contentType = 'application/vnd.ms-powerpoint';
    else if (ext === 'pptx') contentType = 'application/vnd.openxmlformats-officedocument.presentationml.presentation';

    res.setHeader('Content-Disposition', `inline; filename="${String(originalName).replace(/"/g, '')}"`);
    res.setHeader('Content-Type', contentType);
    const fileStream = fs.createReadStream(filePath);
    fileStream.pipe(res);
  } catch (err) {
    res.status(500).json({ success: false, error: err.message || 'Failed to stream document' });
  }
});

router.get('/:id/download', authenticateToken, async (req, res) => {
  try {
    const record = await RepositoryDocument.findOne({ where: { filename: req.params.id } });
    if (!record) return res.status(404).json({ success: false, error: 'Document not found' });

    if (String(record.storage_provider || '').toLowerCase() === 'cloudinary' && record.url) {
      return res.redirect(String(record.url));
    }

    const rel = String(record.url || '').replace(fileUploadService.baseUrl, '').replace(/^\//, '');
    const filePath = path.resolve(fileUploadService.storageBasePath, rel || record.filename);
    if (!fs.existsSync(filePath)) return res.status(404).json({ success: false, error: 'File not found' });
    res.download(filePath, record.title || record.original_name || record.filename);
  } catch (err) {
    res.status(500).json({ success: false, error: err.message || 'Failed to download document' });
  }
});

router.get('/:id/preview', authenticateToken, async (req, res) => {
  try {
    const record = await RepositoryDocument.findOne({ where: { filename: req.params.id } });
    if (!record) return res.status(404).json({ success: false, error: 'Document not found' });
    const ext = path.extname(record.filename).replace('.', '').toLowerCase();
    const isText = ['txt', 'md', 'json', 'xml', 'csv', 'log', 'yaml', 'yml', 'ini', 'conf', 'properties'].includes(ext);

    if (isText) {
      try {
        if (String(record.storage_provider || '').toLowerCase() === 'cloudinary' && record.url) {
          const r = await axios.get(String(record.url), { responseType: 'text', timeout: 8000 });
          const content = typeof r.data === 'string' ? r.data : JSON.stringify(r.data);
          return res.json({ success: true, data: { previewContent: content } });
        }
        const rel = String(record.url || '').replace(fileUploadService.baseUrl, '').replace(/^\//, '');
        const filePath = path.resolve(fileUploadService.storageBasePath, rel || record.filename);
        if (!fs.existsSync(filePath)) return res.status(404).json({ success: false, error: 'File not found' });
        const content = fs.readFileSync(filePath, 'utf8');
        return res.json({ success: true, data: { previewContent: content } });
      } catch (_) {}
    }

    return res.json({
      success: true,
      data: {
        downloadUrl: record.url,
        previewAvailable: false,
        message: 'Inline preview is not available for this file type. Open or download the file instead.',
      },
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message || 'Failed to generate preview' });
  }
});

router.delete('/:id', authenticateToken, async (req, res) => {
  try {
    // Role-based: allow system_admin, project_manager, and uploader to delete
    const isAdmin = ['system_admin','systemAdmin','SystemAdmin','project_manager','projectManager','ProjectManager'].includes(String(req.user.role || ''));
    const record = await RepositoryDocument.findOne({ where: { filename: req.params.id } });
    if (!record) return res.status(404).json({ success: false, error: 'Document not found' });
    const isUploader = record.uploaded_by && req.user && String(req.user.id) === String(record.uploaded_by);
    if (!isAdmin && !isUploader) {
      return res.status(403).json({ success: false, error: 'Not authorized to delete this document' });
    }

    try {
      if (String(record.storage_provider || '').toLowerCase() === 'cloudinary' && record.cloudinary_public_id) {
        await cloudinaryService.destroyByPublicId({
          publicId: record.cloudinary_public_id,
          resourceType: record.cloudinary_resource_type || 'raw',
        });
      } else {
        await fileUploadService.deleteFile(record.filename);
      }
    } catch (_) {}

    await RepositoryDocument.destroy({ where: { filename: record.filename } });
    try { if (global.realtimeEvents) { global.realtimeEvents.emit('document_deleted', { id: record.filename }); } } catch (_) {}
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message || 'Delete failed' });
  }
});

router.put('/:id', authenticateToken, async (req, res) => {
  try {
    const { title, description, tags } = req.body || {};
    const record = await RepositoryDocument.findOne({ where: { filename: req.params.id } });
    if (!record) return res.status(404).json({ success: false, error: 'Document not found' });

    const tagsArr = Array.isArray(tags)
      ? tags
      : (typeof tags === 'string' && tags.trim() !== '' ? tags.split(',').map(s => s.trim()).filter(Boolean) : []);

    await record.update({
      title: typeof title === 'string' && title.trim() !== '' ? title.trim() : record.title,
      description: typeof description === 'string' ? description : record.description,
      tags: tagsArr.length > 0 ? tagsArr.join(',') : record.tags,
    });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message || 'Update failed' });
  }
});

router.post('/:id/view', authenticateToken, async (req, res) => {
  try {
    // No-op for now; acknowledge view for audit compatibility
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Failed to track view' });
  }
});

router.get('/:id/audit', authenticateToken, async (req, res) => {
  try {
    // Return empty audit trail for now
    res.json({ success: true, data: [] });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Failed to load audit' });
  }
});

module.exports = router;
