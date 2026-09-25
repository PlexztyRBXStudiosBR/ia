// Arkher Studio - Storage Routes - Suporte a 15GB por jogo
// Quando DataStore 4MB não aguenta, usa S3 / Supabase

const fs = require('fs');
const path = require('path');

// Mock storage - em produção usa S3 SDK
const mockStorage = new Map(); // projectId -> manifest + chunks

async function storageRoutes(fastify, options) {

  // Save manifest (lista de chunks + metadados)
  fastify.post('/manifest', async (request, reply) => {
    const { userId, projectId, manifest } = request.body;

    console.log(`[Arkher Storage] Save manifest - Project: ${projectId} - User: ${userId} - Size: ${(manifest.meta.totalSize / 1024 / 1024).toFixed(2)} MB`);

    if (manifest.meta.totalSize > 15_000_000_000) {
      return reply.code(400).send({
        error: 'Project too large',
        maxSize: '15GB',
        currentSize: `${(manifest.meta.totalSize / 1024 / 1024 / 1024).toFixed(2)} GB`,
        message: 'Project exceeds 15GB limit. Consider splitting or optimizing with Arkher Auto Optimizer.'
      });
    }

    // Salva manifest
    const key = `${userId}_${projectId}_manifest`;
    mockStorage.set(key, manifest);

    // Em produção: salva no S3
    // await s3.putObject({ Bucket: 'arkher-projects', Key: `${projectId}/manifest.json`, Body: JSON.stringify(manifest) })

    return {
      success: true,
      projectId: projectId,
      totalSize: manifest.meta.totalSize,
      totalSizeMB: (manifest.meta.totalSize / 1024 / 1024).toFixed(2),
      chunkCount: manifest.meta.chunkCount,
      largeChunkCount: manifest.largeChunkKeys.length,
      message: `Manifest saved - ${manifest.meta.chunkCount} chunks - ${(manifest.meta.totalSize / 1024 / 1024).toFixed(2)} MB / 15GB`,
      storage: manifest.meta.totalSize > 10_000_000 ? 'external_s3' : 'datastore',
      mock: true
    };
  });

  // Get manifest
  fastify.get('/manifest/:projectId', async (request, reply) => {
    const { projectId } = request.params;
    const { userId } = request.query;

    const key = `${userId}_${projectId}_manifest`;
    const manifest = mockStorage.get(key);

    if (!manifest) {
      return reply.code(404).send({ error: 'Manifest not found', projectId });
    }

    return {
      success: true,
      manifest: manifest,
      mock: true
    };
  });

  // Upload chunk (50MB max por chunk)
  fastify.post('/chunk', async (request, reply) => {
    const { userId, projectId, chunkKey, chunkData, size } = request.body;

    console.log(`[Arkher Storage] Upload chunk - Project: ${projectId} - Chunk: ${chunkKey} - Size: ${(size / 1024 / 1024).toFixed(2)} MB`);

    if (size > 50_000_000) {
      return reply.code(400).send({
        error: 'Chunk too large',
        maxChunkSize: '50MB',
        currentSize: `${(size / 1024 / 1024).toFixed(2)} MB`,
        suggestion: 'Split chunk into smaller pieces or use more chunks'
      });
    }

    const key = `${userId}_${projectId}_chunk_${chunkKey}`;
    mockStorage.set(key, {
      chunkKey: chunkKey,
      data: chunkData,
      size: size,
      uploadedAt: Date.now(),
      projectId: projectId,
      userId: userId
    });

    // Em produção: S3 multipart upload
    // await s3.putObject({ Bucket: 'arkher-projects', Key: `${projectId}/chunks/${chunkKey}.json`, Body: chunkData })

    return {
      success: true,
      chunkKey: chunkKey,
      size: size,
      sizeMB: (size / 1024 / 1024).toFixed(2),
      url: `https://arkher-cdn.fly.dev/projects/${projectId}/chunks/${chunkKey}.json`,
      mock: true,
      message: `Chunk ${chunkKey} uploaded - ${(size / 1024 / 1024).toFixed(2)} MB`
    };
  });

  // Download chunk
  fastify.get('/chunk/:projectId/:chunkKey', async (request, reply) => {
    const { projectId, chunkKey } = request.params;
    const { userId } = request.query;

    const key = `${userId}_${projectId}_chunk_${chunkKey}`;
    const chunk = mockStorage.get(key);

    if (!chunk) {
      return reply.code(404).send({ error: 'Chunk not found', projectId, chunkKey });
    }

    return {
      success: true,
      chunk: chunk,
      mock: true
    };
  });

  // List chunks for project
  fastify.get('/chunks/:projectId', async (request, reply) => {
    const { projectId } = request.params;
    const { userId } = request.query;

    const chunks = [];
    for (const [key, value] of mockStorage.entries()) {
      if (key.startsWith(`${userId}_${projectId}_chunk_`)) {
        chunks.push({
          chunkKey: value.chunkKey,
          size: value.size,
          sizeMB: (value.size / 1024 / 1024).toFixed(2),
          uploadedAt: value.uploadedAt
        });
      }
    }

    const totalSize = chunks.reduce((sum, c) => sum + c.size, 0);

    return {
      success: true,
      projectId: projectId,
      chunks: chunks,
      totalChunks: chunks.length,
      totalSize: totalSize,
      totalSizeMB: (totalSize / 1024 / 1024).toFixed(2),
      totalSizeGB: (totalSize / 1024 / 1024 / 1024).toFixed(3),
      maxSizeGB: 15,
      usagePercent: ((totalSize / 15_000_000_000) * 100).toFixed(2),
      mock: true
    };
  });

  // Delete project (all chunks + manifest)
  fastify.delete('/:projectId', async (request, reply) => {
    const { projectId } = request.params;
    const { userId } = request.query;

    let deleted = 0;
    for (const key of mockStorage.keys()) {
      if (key.startsWith(`${userId}_${projectId}_`)) {
        mockStorage.delete(key);
        deleted++;
      }
    }

    console.log(`[Arkher Storage] Deleted project ${projectId} - ${deleted} keys`);

    return {
      success: true,
      projectId: projectId,
      deletedKeys: deleted,
      mock: true
    };
  });

  // Stats - mostra uso total
  fastify.get('/stats/:userId', async (request, reply) => {
    const { userId } = request.params;

    let totalProjects = 0;
    let totalSize = 0;
    const projects = [];

    for (const [key, value] of mockStorage.entries()) {
      if (key.includes(`${userId}_`) && key.endsWith('_manifest')) {
        totalProjects++;
        totalSize += value.meta.totalSize;
        projects.push({
          projectId: value.meta.projectId,
          name: value.meta.name,
          size: value.meta.totalSize,
          sizeMB: (value.meta.totalSize / 1024 / 1024).toFixed(2),
          sizeGB: (value.meta.totalSize / 1024 / 1024 / 1024).toFixed(3),
          chunkCount: value.meta.chunkCount,
          updatedAt: value.meta.updatedAt
        });
      }
    }

    projects.sort((a, b) => b.size - a.size);

    return {
      success: true,
      userId: userId,
      totalProjects: totalProjects,
      totalSize: totalSize,
      totalSizeMB: (totalSize / 1024 / 1024).toFixed(2),
      totalSizeGB: (totalSize / 1024 / 1024 / 1024).toFixed(3),
      maxSizeGB: 15,
      projects: projects,
      mock: true,
      message: `User ${userId} has ${totalProjects} projects using ${(totalSize / 1024 / 1024 / 1024).toFixed(3)} GB / 15GB`
    };
  });

  // Estimate size before upload
  fastify.post('/estimate', async (request, reply) => {
    const { entityCount, avgEntitySize } = request.body;

    const estimatedSize = entityCount * (avgEntitySize || 2048);
    const chunkCount = Math.ceil(estimatedSize / 50_000_000);
    const needsExternal = estimatedSize > 10_000_000;

    return {
      entityCount: entityCount,
      avgEntitySize: avgEntitySize || 2048,
      estimatedSize: estimatedSize,
      estimatedSizeMB: (estimatedSize / 1024 / 1024).toFixed(2),
      estimatedSizeGB: (estimatedSize / 1024 / 1024 / 1024).toFixed(4),
      chunkCount: chunkCount,
      needsExternalStorage: needsExternal,
      storageType: needsExternal ? 'external_s3' : 'datastore',
      maxSizeGB: 15,
      canFit: estimatedSize < 15_000_000_000,
      message: needsExternal 
        ? `Project needs external storage (S3) - ${chunkCount} chunks of 50MB`
        : `Project fits in DataStore with chunking - ${chunkCount} chunks`
    };
  });
}

module.exports = storageRoutes;
