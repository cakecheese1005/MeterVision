import { apiClient } from './client'
import type { Notification } from '../types/api'
export async function listNotifications(){ const r=await apiClient.get<Notification[]>('/notifications/'); return r.data }
export async function markRead(id:string,is_read=true){ const r=await apiClient.put<Notification>(`/notifications/${id}`,{is_read}); return r.data }
export async function markAllRead(){ await apiClient.put('/notifications/read-all') }
