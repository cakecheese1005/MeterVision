export interface APIResponse<T> { success:boolean; message:string; data:T; timestamp:string }
export interface SuccessResponse { success:boolean; message:string; timestamp:string }
export interface ErrorResponseBody { success:false; status_code:number; message:string; errors?:string[]|null; timestamp:string }
