import { apiClient } from './client'
import type { APIResponse, SuccessResponse } from '../types/common'
import type { LoginRequest, LoginData, UserProfile, UpdateProfileRequest } from '../types/api'

export async function login(payload:LoginRequest){ const r=await apiClient.post<APIResponse<LoginData>>('/auth/login',payload); return r.data.data }
export async function logout(){ await apiClient.post<SuccessResponse>('/auth/logout') }
export async function getProfile(){ const r=await apiClient.get<APIResponse<UserProfile>>('/auth/me'); return r.data.data }
export async function updateProfile(payload:UpdateProfileRequest){ const r=await apiClient.put<APIResponse<UserProfile>>('/auth/profile',payload); return r.data.data }
