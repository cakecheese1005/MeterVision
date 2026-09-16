import { apiClient } from './client'
import type { Consumer } from '../types/api'
export async function listConsumers(page=1,page_size=20){ const r=await apiClient.get<Consumer[]>('/consumers/',{params:{page,page_size}}); return r.data }
export async function searchConsumers(payload:Partial<Pick<Consumer,'consumer_number'|'account_number'|'consumer_name'|'subdivision'>>){ const r=await apiClient.post<Consumer[]>('/consumers/search',payload); return r.data }
export async function getConsumer(id:string){ const r=await apiClient.get<Consumer>(`/consumers/${id}`); return r.data }
export async function createConsumer(payload:Omit<Consumer,'id'>){ const r=await apiClient.post<Consumer>('/consumers/',payload); return r.data }
export async function updateConsumer(id:string,payload:Partial<Consumer>){ const r=await apiClient.put<Consumer>(`/consumers/${id}`,payload); return r.data }
export async function deleteConsumer(id:string){ await apiClient.delete(`/consumers/${id}`) }
