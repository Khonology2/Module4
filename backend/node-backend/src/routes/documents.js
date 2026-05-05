const express = require('express');
const router = express.Router();
const path = require('path');
const fs = require('fs');
const { authenticateToken, requireRole } = require('../middleware/auth');
const { Sprint, DeliverableSprint, Project } = require('../models');
const { Op } = require('sequelize');
const fileUploadService = require('../services/fileUploadService');

function toRepositoryFile(file) {
  const ext = path.extname(file.filename).replace('.', '').toLowerCase();
  const sizeInMB = Math.round((file.size / (1024 * 1024)) * 100) / 100;
  return {
    id: file.filename,
    name: file.title || file.originalName || file.filename,
    fileType: ext || 'file',
    uploaded_at: new Date(file.uploadDate).toISOString(),
    uploaded_by: file.uploadedBy || 'system',
    size: file.size,
    size_in_mb: sizeInMB,
    description: file.description || '',
    tags: Array.isArray(file.tags) ? file.tags.join(',') : (file.tags || ''),
    file_path: file.url,
    uploader_name: file.uploaderName || 'System',
  };
}

router.get('/', authenticateToken, async (req, res) => {
  try {
    const { search, fileType } = req.query;
    const project_id = req.query.project_id ?? req.query.projectId;
    const project_key = req.query.project_key ?? req.query.projectKey;
    const sprint_id = req.query.sprint_id ?? req.query.sprintId;
    const deliverable_id = req.query.deliverable_id ?? req.query.deliverableId;
    const files = await fileUploadService.listFiles();

    let filtered = files;

    const normalizeId = (v) => (typeof v === 'string' && v.trim() !== '' ? v.trim() : '');

    // Project-scoped filtering
    const pid = normalizeId(project_id);
    const pkey = normalizeId(project_key);
    if (pid || pkey) {
      let project = null;
      if (pid) {
        try { project = await Project.findByPk(pid); } catch (_) {}
      }
      if (!project && pkey) {
        try { project = await Project.findOne({ where: { key: pkey } }); } catch (_) {}
      }
      if (project) {
        const sprints = await Sprint.findAll({ where: { project_id: project.id }, attributes: ['id'] });
        const sprintIds = new Set(sprints.map(s => String(s.id)));
        let deliverableIds = new Set();
        if (sprints.length > 0) {
          const rows = await DeliverableSprint.findAll({ where: { sprint_id: { [Op.in]: Array.from(sprintIds) } }, attributes: ['deliverable_id'] });
          deliverableIds = new Set(rows.map(r => String(r.deliverable_id)));
        }
        const containsAnyId = (text, set) => {
          const t = String(text || '');
          for (const id of set) {
            if (t.includes(`/sprints/${id}/`) || t.includes(`/deliverables/${id}/`) || t.includes(`/${id}/`) || t.endsWith(`/${id}`)) return true;
          }
          return false;
        };
        const hasAnyTag = (tagsArr, key, ids) => {
          const arr = Array.isArray(tagsArr) ? tagsArr : (typeof tagsArr === 'string' ? tagsArr.split(',').map(s=>s.trim()) : []);
          for (const id of ids) {
            const kv = `${key}:${id}`;
            if (arr.some(tag => String(tag || '').toLowerCase() === String(kv).toLowerCase())) return true;
          }
          return false;
        };
        filtered = filtered.filter(f => {
          const url = f.url || '';
          const tags = f.tags || [];
          if (pid && hasAnyTag(tags, 'project', [pid])) return true;
          if (pkey && hasAnyTag(tags, 'projectKey', [pkey])) return true;
          if (containsAnyId(url, sprintIds)) return true;
          if (containsAnyId(url, deliverableIds)) return true;
          if (hasAnyTag(tags, 'sprint', Array.from(sprintIds))) return true;
          if (hasAnyTag(tags, 'deliverable', Array.from(deliverableIds))) return true;
          return false;
        });
      } else {
        filtered = [];
      }
    }

    const sid = normalizeId(sprint_id);
    if (sid) {
      filtered = filtered.filter(f => {
        const url = String(f.url || '');
        const tags = f.tags || [];
        const arr = Array.isArray(tags) ? tags : (typeof tags === 'string' ? tags.split(',').map(s=>s.trim()) : []);
        const kv = `sprint:${sid}`.toLowerCase();
        if (arr.some(tag => String(tag || '').toLowerCase() === kv)) return true;
        return url.includes(`/sprints/${sid}/`) || url.includes(`/${sid}/`) || url.endsWith(`/${sid}`);
      });
    }

    const did = normalizeId(deliverable_id);
    if (did) {
      filtered = filtered.filter(f => {
        const url = String(f.url || '');
        const tags = f.tags || [];
        const arr = Array.isArray(tags) ? tags : (typeof tags === 'string' ? tags.split(',').map(s=>s.trim()) : []);
        const kv = `deliverable:${did}`.toLowerCase();
        if (arr.some(tag => String(tag || '').toLowerCase() === kv)) return true;
        return url.includes(`/deliverables/${did}/`) || url.includes(`/${did}/`) || url.endsWith(`/${did}`);
      });
    }

    let data = filtered.map(toRepositoryFile);
    const s = typeof search === 'string' ? search.trim().toLowerCase() : '';
    const ft = typeof fileType === 'string' ? fileType.trim().toLowerCase() : '';
    if (s) {
      data = data.filter(d => (d.name && d.name.toLowerCase().includes(s)) || (d.description && d.description.toLowerCase().includes(s)) || (d.tags && d.tags.toLowerCase().includes(s)));
    }
    if (ft) {
      data = data.filter(d => (d.fileType || '').toLowerCase() === ft);
    }
    res.json({ success: true, data });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message || 'Failed to list documents' });
  }
});

// Upload not implemented here; use /api/v1/files/upload instead

router.get('/:id', authenticateToken, async (req, res) => {
  try {
    const files = await fileUploadService.listFiles();
    const file = files.find(f => f.filename === req.params.id);
    if (!file) return res.status(404).json({ success: false, error: 'Document not found' });
    res.json({ success: true, data: toRepositoryFile(file) });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message || 'Failed to get document' });
  }
});

router.get('/:id/download', authenticateToken, async (req, res) => {
  try {
    const files = await fileUploadService.listFiles();
    const file = files.find(f => f.filename === req.params.id);
    if (!file) return res.status(404).json({ success: false, error: 'Document not found' });
    const rel = file.url.replace(fileUploadService.baseUrl, '').replace(/^\//, '');
    const filePath = path.resolve(fileUploadService.storageBasePath, rel || file.filename);
    if (!fs.existsSync(filePath)) return res.status(404).json({ success: false, error: 'File not found' });
    res.download(filePath, file.title || file.originalName || file.filename);
  } catch (err) {
    res.status(500).json({ success: false, error: err.message || 'Failed to download document' });
  }
});

router.get('/:id/preview', authenticateToken, async (req, res) => {
  try {
    const files = await fileUploadService.listFiles();
    const file = files.find(f => f.filename === req.params.id);
    if (!file) return res.status(404).json({ success: false, error: 'Document not found' });
    const ext = path.extname(file.filename).replace('.', '').toLowerCase();
    if (['txt', 'md', 'json', 'xml', 'csv'].includes(ext)) {
      const rel = file.url.replace(fileUploadService.baseUrl, '').replace(/^\//, '');
      const filePath = path.resolve(fileUploadService.storageBasePath, rel || file.filename);
      if (!fs.existsSync(filePath)) return res.status(404).json({ success: false, error: 'File not found' });
      const content = fs.readFileSync(filePath, 'utf8');
      return res.json({ success: true, data: { previewContent: content } });
    }
    return res.json({ success: true, data: { downloadUrl: file.url } });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message || 'Failed to generate preview' });
  }
});

router.delete('/:id', authenticateToken, async (req, res) => {
  try {
    // Role-based: allow system_admin, project_manager, and uploader to delete
    const isAdmin = ['system_admin','systemAdmin','SystemAdmin','project_manager','projectManager','ProjectManager'].includes(String(req.user.role || ''));
    let uploaderId = null;
    try {
      const files = await fileUploadService.listFiles();
      const file = files.find(f => f.filename === req.params.id);
      if (file) {
        // read meta to get uploadedBy
        const rel = file.url.replace(fileUploadService.baseUrl, '').replace(/^\//, '');
        const filePath = path.resolve(fileUploadService.storageBasePath, rel || file.filename);
        try {
          const metaRaw = fs.readFileSync(`${filePath}.meta.json`, 'utf8');
          const meta = JSON.parse(metaRaw);
          uploaderId = meta && meta.uploadedBy ? String(meta.uploadedBy) : null;
        } catch (_) {}
      }
    } catch (_) {}
    const isUploader = uploaderId && req.user && String(req.user.id) === uploaderId;
    if (!isAdmin && !isUploader) {
      return res.status(403).json({ success: false, error: 'Not authorized to delete this document' });
    }

    const ok = await fileUploadService.deleteFile(req.params.id);
    if (!ok) return res.status(404).json({ success: false, error: 'File not found' });
    try { if (global.realtimeEvents) { global.realtimeEvents.emit('document_deleted', { id: req.params.id }); } } catch (_) {}
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message || 'Delete failed' });
  }
});

router.put('/:id', authenticateToken, async (req, res) => {
  try {
    const { title, description, tags } = req.body || {};
    const files = await fileUploadService.listFiles();
    const file = files.find(f => f.filename === req.params.id);
    if (!file) return res.status(404).json({ success: false, error: 'Document not found' });
    const rel = file.url.replace(fileUploadService.baseUrl, '').replace(/^\//, '');
    const filePath = path.resolve(fileUploadService.storageBasePath, rel || file.filename);
    let meta = {};
    try { meta = JSON.parse(fs.readFileSync(`${filePath}.meta.json`, 'utf8')); } catch (_) {}
    const updated = {
      ...meta,
      title: typeof title === 'string' && title.trim() !== '' ? title.trim() : (meta.title || file.originalName || file.filename),
      description: typeof description === 'string' ? description : (meta.description || ''),
      tags: Array.isArray(tags) ? tags : (typeof tags === 'string' && tags.trim() !== '' ? tags.split(',').map(s=>s.trim()) : (meta.tags || []))
    };
    fs.writeFileSync(`${filePath}.meta.json`, JSON.stringify(updated));
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
