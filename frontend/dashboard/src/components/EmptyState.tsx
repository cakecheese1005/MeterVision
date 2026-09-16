import type { ReactNode } from 'react'

export function EmptyState({
  icon,
  title,
  description,
  action,
}: {
  icon?: ReactNode
  title: string
  description?: string
  action?: ReactNode
}) {
  return (
    <div className="flex flex-col items-center justify-center rounded-xl border border-dashed border-slate-200 bg-white px-6 py-16 text-center">
      {icon && <div className="mb-4 text-slate-300">{icon}</div>}
      <h3 className="text-sm font-semibold text-slate-800">{title}</h3>
      {description && <p className="mt-1.5 max-w-sm text-sm text-slate-500">{description}</p>}
      {action && <div className="mt-5">{action}</div>}
    </div>
  )
}

export function ErrorState({
  title = 'Couldn\u2019t load this',
  description,
  onRetry,
}: {
  title?: string
  description?: string
  onRetry?: () => void
}) {
  return (
    <div className="flex flex-col items-center justify-center rounded-xl border border-rose-100 bg-rose-50/60 px-6 py-16 text-center">
      <h3 className="text-sm font-semibold text-rose-800">{title}</h3>
      {description && <p className="mt-1.5 max-w-md text-sm text-rose-600">{description}</p>}
      {onRetry && (
        <button
          onClick={onRetry}
          className="mt-5 rounded-lg bg-rose-600 px-4 py-2 text-sm font-medium text-white hover:bg-rose-700"
        >
          Try again
        </button>
      )}
    </div>
  )
}

export function ComingSoonState({ moduleName }: { moduleName: string }) {
  return (
    <EmptyState
      title="Backend functionality not currently available."
      description={`The FastAPI backend does not expose a working, mounted API for ${moduleName} yet, so this page has nothing real to show. It will light up as soon as that endpoint exists.`}
    />
  )
}
