import { apiClient } from './client'
import type { LCRCase, LCRStatus } from '../types/api'
export async function listLCR(){ const r=await apiClient.get<LCRCase[]>('/lcr/'); return r.data }
export async function createLCR(payload:{reading_id:string;lcr_user_id:string}){ const r=await apiClient.post<LCRCase>('/lcr/',payload); return r.data }
export async function approveLCR(id:string,payload:{status:LCRStatus;remarks?:string}){ const r=await apiClient.put<LCRCase>(`/lcr/${id}/approve`,payload); return r.data }
export async function rejectLCR(id:string,payload:{status:LCRStatus;remarks?:string}){ const r=await apiClient.put<LCRCase>(`/lcr/${id}/reject`,payload); return r.data }
