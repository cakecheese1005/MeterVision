import { apiClient } from './client'
import type { Anomaly, AnomalyStatus } from '../types/api'
export async function listAnomalies(){ const r=await apiClient.get<Anomaly[]>('/anomalies/'); return r.data }
export async function getAnomaly(id:string){ const r=await apiClient.get<Anomaly>(`/anomalies/${id}`); return r.data }
export async function updateAnomaly(id:string,payload:{reason?:string;severity?:string;status?:AnomalyStatus}){ const r=await apiClient.put<Anomaly>(`/anomalies/${id}`,payload); return r.data }
