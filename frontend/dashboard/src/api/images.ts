import { apiClient } from './client'
import type { Image } from '../types/api'
export async function getImage(id:string){ const r=await apiClient.get<Image>(`/images/${id}`); return r.data }
export async function deleteImage(id:string){ await apiClient.delete(`/images/${id}`) }
export async function uploadImage(payload:{reading_id:string;latitude:number;longitude:number;file:File}){ const form=new FormData(); form.append('reading_id',payload.reading_id); form.append('latitude',String(payload.latitude)); form.append('longitude',String(payload.longitude)); form.append('file',payload.file); const r=await apiClient.post('/images/upload',form); return r.data }
