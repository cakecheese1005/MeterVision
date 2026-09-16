export interface APIResponse<T> { success: boolean; message: string; data: T; timestamp: string }
export interface SuccessResponse { success: boolean; message: string; timestamp: string }
export type UserRole = 'admin' | 'officer' | 'lcr'
export type ReadingStatus = 'pending' | 'completed' | 'review' | 'rejected'
export type ImageQuality = 'ok' | 'blur' | 'reflection' | 'irrelevant'
export type LCRStatus = 'pending' | 'approved' | 'rejected' | 'revisit_required'
export type AnomalyStatus = 'pending' | 'resolved'
export type SyncStatus = 'pending' | 'success' | 'failed'
export type MeterType = 'digital' | 'electromechanical'
export type NotificationType = 'assignment' | 'anomaly' | 'lcr' | 'sync' | 'system'
export type AIClassification = string

export interface DashboardFilter { from_date?: string; to_date?: string; subdivision?: string; officer_id?: string }
export interface DashboardResponse { summary: { total_consumers:number; total_readings:number; completed_today:number; pending_readings:number; anomalies:number; pending_lcr:number; offline_pending:number }; trends: {date:string; readings:number; anomalies:number}[] }

export interface Reading { id:string; consumer_id:string; officer_id:string; reading_value:number; previous_reading:number|null; units_consumed:number|null; status:ReadingStatus; created_at:string }
export interface Image { id:string; reading_id:string; image_url:string; quality:ImageQuality; classification:AIClassification; blur_score:number|null; uploaded_at:string }
export interface OCRResult { [key:string]: unknown; id?:string; reading_id?:string; extracted_value?:number|string|null; confidence?:number|null; status?:string|null }
export interface Anomaly { id:string; reading_id:string; reason:string; severity:string; status:AnomalyStatus; created_at:string }
export interface ReadingDetails { reading:Reading; image:Image|null; ocr:OCRResult|null; anomaly:Anomaly|null }
export interface Consumer { id:string; consumer_number:string; account_number:string; consumer_name:string; address:string; meter_number:string; meter_type:MeterType; subdivision:string|null; feeder:string|null; cycle:string|null }
export interface User { id:string; name:string; email:string; role:UserRole }
export interface LCRCase { id:string; reading_id:string; assigned_to:string|null; status:LCRStatus; remarks:string|null; updated_at:string }
export interface Notification { id:string; title:string; message:string; notification_type:NotificationType; is_read:boolean; created_at:string }
export interface SyncQueueItem { id:string; device_id:string|null; reading_id:string; status:SyncStatus; retry_count:number; created_at:string }

export interface LoginRequest { email:string; password:string }
export interface LoginData { access_token:string; refresh_token:string; token_type:string; user_id:string; name:string; email:string; role:UserRole }
export interface UserProfile { id:string; name:string; email:string; role:UserRole; phone_number?:string|null; last_login?:string|null; created_at:string }
export interface UpdateProfileRequest { name?:string; phone_number?:string }
