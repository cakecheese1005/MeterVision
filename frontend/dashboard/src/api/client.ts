import axios, { AxiosError } from 'axios'
import type { ErrorResponseBody } from '../types/common'

export const API_BASE_URL = (import.meta.env.VITE_API_BASE_URL || 'http://127.0.0.1:8000').replace(/\/$/, '')
export const ACCESS_TOKEN_KEY = 'mv_access_token'
export const REFRESH_TOKEN_KEY = 'mv_refresh_token'

export const apiClient = axios.create({ baseURL: API_BASE_URL, timeout: 20000 })

apiClient.interceptors.request.use((config) => {
  const token = localStorage.getItem(ACCESS_TOKEN_KEY)
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

let onUnauthorized: (() => void) | null = null
export function registerUnauthorizedHandler(handler: () => void) { onUnauthorized = handler }

apiClient.interceptors.response.use(
  (response) => response,
  (error: AxiosError<ErrorResponseBody | {detail?:unknown}>) => {
    if (error.response?.status === 401) onUnauthorized?.()
    return Promise.reject(error)
  },
)

export function extractErrorMessage(error: unknown, fallback='Request failed.') {
  if (axios.isAxiosError(error)) {
    const detail = (error.response?.data as {detail?:unknown}|undefined)?.detail
    if (typeof detail === 'string') return detail
    if (detail && typeof detail === 'object' && 'message' in detail) {
      const msg=(detail as {message?:unknown}).message
      if (typeof msg==='string') return msg
    }
    if (error.message) return error.message
  }
  return fallback
}
