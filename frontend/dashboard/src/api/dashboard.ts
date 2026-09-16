import { apiClient } from './client'
import type { DashboardFilter, DashboardResponse } from '../types/api'
export async function getDashboard(filters:DashboardFilter={}) { const r=await apiClient.get<DashboardResponse>('/dashboard',{params:filters}); return r.data }
