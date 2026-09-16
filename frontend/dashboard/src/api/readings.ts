import { apiClient } from './client'
import type { Reading, ReadingDetails, ReadingStatus } from '../types/api'
export interface ReadingFilters { status?:ReadingStatus; officer_id?:string; subdivision?:string; from_date?:string; to_date?:string }
export async function listReadings(filters:ReadingFilters={}) { const r=await apiClient.get<Reading[]>('/readings/',{params:filters}); return r.data }
export async function getReading(id:string){ const r=await apiClient.get<Reading>(`/readings/${id}`); return r.data }
export async function getReadingDetails(id:string){ const r=await apiClient.get<ReadingDetails>(`/readings/${id}/details`); return r.data }
export async function approveReading(id:string,status:ReadingStatus,remarks?:string){ const r=await apiClient.post(`/readings/${id}/approve`,{status,remarks}); return r.data }
export async function rejectReading(id:string,status:ReadingStatus='rejected',remarks?:string){ const r=await apiClient.post(`/readings/${id}/reject`,{status,remarks}); return r.data }
export async function updateReading(id:string,payload:Partial<Pick<Reading,'reading_value'|'status'>> & {latitude?:number;longitude?:number}){ const r=await apiClient.put(`/readings/${id}`,payload); return r.data }
export async function calculateUnits(id:string){ const r=await apiClient.get(`/readings/${id}/units`); return r.data }
export async function detectAnomaly(id:string){ const r=await apiClient.get(`/readings/${id}/anomaly`); return r.data }
