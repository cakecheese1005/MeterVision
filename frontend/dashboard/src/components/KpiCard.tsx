import type { ReactNode } from 'react'

export function KpiCard({
  label,
  value,
  icon,
  accent = 'slate',
  hint,
}: {
  label: string
  value: ReactNode
  icon?: ReactNode
  accent?: 'slate' | 'amber' | 'emerald' | 'sky' | 'rose'
  hint?: string
}) {
  const ring: Record<string, string> = {
    slate: 'bg-slate-100 text-slate-600',
    amber: 'bg-amber-50 text-amber-600',
    emerald: 'bg-emerald-50 text-emerald-600',
    sky: 'bg-sky-50 text-sky-600',
    rose: 'bg-rose-50 text-rose-600',
  }

  return (
    <div className="rounded-xl border border-slate-200 bg-white p-5 shadow-panel">
      <div className="flex items-start justify-between">
        <div>
          <p className="text-xs font-medium uppercase tracking-wide text-slate-400">{label}</p>
          <p className="mt-2 text-2xl font-bold text-slate-900">{value}</p>
          {hint && <p className="mt-1 text-xs text-slate-400">{hint}</p>}
        </div>
        {icon && (
          <div className={`flex h-9 w-9 items-center justify-center rounded-lg ${ring[accent]}`}>
            {icon}
          </div>
        )}
      </div>
    </div>
  )
}
