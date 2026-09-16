import { apiClient } from './client'
import type { User, UserRole } from '../types/api'
export async function listUsers(){ const r=await apiClient.get<User[]>('/users/'); return r.data }
export async function listOfficers(){ const r=await apiClient.get<User[]>('/users/officers'); return r.data }
export async function createUser(payload:{name:string;email:string;password:string;role:UserRole}){ const r=await apiClient.post<User>('/users/',payload); return r.data }
export async function updateUser(id:string,payload:{name?:string;role?:UserRole}){ const r=await apiClient.put<User>(`/users/${id}`,payload); return r.data }
export async function deleteUser(id:string){ await apiClient.delete(`/users/${id}`) }
