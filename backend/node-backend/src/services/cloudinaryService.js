"use strict";

const { v2: cloudinary } = require('cloudinary');

const resolveCloudinaryConfig = () => {
  const cloudName =
    process.env.CLOUDINARY_CLOUD_NAME ||
    process.env.Cloud_name ||
    process.env.cloud_name ||
    '';
  const apiKey =
    process.env.CLOUDINARY_API_KEY ||
    process.env.API_key ||
    process.env.api_key ||
    '';
  const apiSecret =
    process.env.CLOUDINARY_API_SECRET ||
    process.env.API_secret ||
    process.env.api_secret ||
    '';

  if (!cloudName || !apiKey || !apiSecret) return null;
  return { cloud_name: cloudName, api_key: apiKey, api_secret: apiSecret };
};

let configured = false;
const ensureConfigured = () => {
  if (configured) return true;
  const cfg = resolveCloudinaryConfig();
  if (!cfg) return false;
  cloudinary.config(cfg);
  configured = true;
  return true;
};

const uploadBuffer = async ({
  buffer,
  folder,
  publicId,
  originalFilename,
  resourceType = 'auto',
  tags,
}) => {
  if (!ensureConfigured()) {
    throw new Error('Cloudinary is not configured');
  }

  const safeFolder = String(folder || '')
    .replace(/\\/g, '/')
    .replace(/^\/+/, '')
    .replace(/\/+$/, '');

  const uploadOptions = {
    resource_type: resourceType,
    use_filename: false,
    unique_filename: true,
    overwrite: false,
  };
  if (safeFolder) uploadOptions.folder = safeFolder;
  if (publicId) uploadOptions.public_id = String(publicId);
  if (originalFilename) uploadOptions.filename_override = String(originalFilename);
  if (Array.isArray(tags) && tags.length > 0) uploadOptions.tags = tags;

  return new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(uploadOptions, (error, result) => {
      if (error) return reject(error);
      resolve(result);
    });
    stream.end(buffer);
  });
};

const destroyByPublicId = async ({ publicId, resourceType = 'raw' }) => {
  if (!ensureConfigured()) return { result: 'not_configured' };
  if (!publicId) return { result: 'missing_public_id' };
  return cloudinary.uploader.destroy(String(publicId), {
    resource_type: resourceType || 'raw',
    invalidate: true,
  });
};

module.exports = {
  isConfigured: () => !!resolveCloudinaryConfig(),
  uploadBuffer,
  destroyByPublicId,
};
