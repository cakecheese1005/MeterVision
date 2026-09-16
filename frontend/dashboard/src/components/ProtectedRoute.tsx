import { Navigate, useLocation } from 'react-router-dom'
import type { ReactNode } from 'react'
import { useAuth } from '../hooks/useAuth'
import { Spinner } from './Spinner'
export function ProtectedRoute({children,roles}:{children:ReactNode;roles?:string[]}){ const {isAuthenticated,isLoading,user}=useAuth(); const loc=useLocation(); if(isLoading)return <div className="flex h-screen items-center justify-center"><Spinner className="h-6 w-6"/></div>; if(!isAuthenticated)return <Navigate to="/login" state={{from:loc}} replace/>; if(roles && user && !roles.includes(user.role)) return <Navigate to="/" replace/>; return <>{children}</> }
