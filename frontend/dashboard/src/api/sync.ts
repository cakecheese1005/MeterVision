import { apiClient } from './client'
import type { SyncQueueItem } from '../types/api'
export async function getPendingSync(){ const r=await apiClient.get<SyncQueueItem[]>('/sync/pending'); return r.data }
export async function retryFailedSync(){ const r=await apiClient.post<SyncQueueItem[]>('/sync/retry-failed'); return r.data }
export async function markSynced(id:string){ const r=await apiClient.post<SyncQueueItem>(`/sync/mark-synced/${id}`); return r.data }
export async function markFailed(id:string){ const r=await apiClient.post<SyncQueueItem>(`/sync/mark-failed/${id}`); return r.data }
