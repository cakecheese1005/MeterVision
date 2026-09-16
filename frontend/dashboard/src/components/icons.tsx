import type { SVGProps } from 'react'

type IconProps = SVGProps<SVGSVGElement>

const base = {
  fill: 'none',
  stroke: 'currentColor',
  strokeWidth: 1.8,
  strokeLinecap: 'round' as const,
  strokeLinejoin: 'round' as const,
  viewBox: '0 0 24 24',
}

export const GaugeIcon = (props: IconProps) => (
  <svg {...base} {...props}>
    <path d="M12 21a9 9 0 100-18 9 9 0 000 18Z" />
    <path d="M12 12l4-4" />
    <path d="M8 12a4 4 0 018-2" />
  </svg>
)

export const ListIcon = (props: IconProps) => (
  <svg {...base} {...props}>
    <path d="M4 6h16M4 12h16M4 18h16" />
  </svg>
)

export const ImageIcon = (props: IconProps) => (
  <svg {...base} {...props}>
    <rect x="3" y="3" width="18" height="18" rx="2" />
    <circle cx="8.5" cy="8.5" r="1.5" />
    <path d="M21 15l-5-5L5 21" />
  </svg>
)

export const SyncIcon = (props: IconProps) => (
  <svg {...base} {...props}>
    <path d="M21 12a9 9 0 01-15.5 6.5L3 16" />
    <path d="M3 12a9 9 0 0115.5-6.5L21 8" />
    <path d="M21 3v5h-5" />
    <path d="M3 21v-5h5" />
  </svg>
)

export const AlertTriangleIcon = (props: IconProps) => (
  <svg {...base} {...props}>
    <path d="M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z" />
    <path d="M12 9v4" />
    <path d="M12 17h.01" />
  </svg>
)

export const FileTextIcon = (props: IconProps) => (
  <svg {...base} {...props}>
    <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z" />
    <path d="M14 2v6h6" />
    <path d="M9 13h6M9 17h6M9 9h1" />
  </svg>
)

export const BellIcon = (props: IconProps) => (
  <svg {...base} {...props}>
    <path d="M18 8a6 6 0 10-12 0c0 7-3 9-3 9h18s-3-2-3-9" />
    <path d="M13.73 21a2 2 0 01-3.46 0" />
  </svg>
)

export const BarChartIcon = (props: IconProps) => (
  <svg {...base} {...props}>
    <path d="M3 3v18h18" />
    <rect x="7" y="12" width="3" height="6" />
    <rect x="12" y="8" width="3" height="10" />
    <rect x="17" y="5" width="3" height="13" />
  </svg>
)

export const UserIcon = (props: IconProps) => (
  <svg {...base} {...props}>
    <circle cx="12" cy="8" r="4" />
    <path d="M4 21c0-4.4 3.6-7 8-7s8 2.6 8 7" />
  </svg>
)

export const UsersIcon = (props: IconProps) => (
  <svg {...base} {...props}>
    <circle cx="9" cy="8" r="3.2" />
    <path d="M2.5 20c0-3.6 2.9-6 6.5-6s6.5 2.4 6.5 6" />
    <path d="M16 8.2a3.2 3.2 0 010 6" />
    <path d="M21.5 20c0-2.9-1.9-5-4.5-5.7" />
  </svg>
)

export const LogOutIcon = (props: IconProps) => (
  <svg {...base} {...props}>
    <path d="M9 21H5a2 2 0 01-2-2V5a2 2 0 012-2h4" />
    <path d="M16 17l5-5-5-5" />
    <path d="M21 12H9" />
  </svg>
)

export const RefreshIcon = (props: IconProps) => (
  <svg {...base} {...props}>
    <path d="M21 12a9 9 0 01-15.5 6.5L3 16" />
    <path d="M3 12a9 9 0 0115.5-6.5L21 8" />
    <path d="M21 3v5h-5" />
    <path d="M3 21v-5h5" />
  </svg>
)

export const UploadIcon = (props: IconProps) => (
  <svg {...base} {...props}>
    <path d="M12 16V4" />
    <path d="M6 10l6-6 6 6" />
    <path d="M4 20h16" />
  </svg>
)

export const PlusIcon = (props: IconProps) => (
  <svg {...base} {...props}>
    <path d="M12 5v14M5 12h14" />
  </svg>
)

export const SearchIcon = (props: IconProps) => (
  <svg {...base} {...props}>
    <circle cx="11" cy="11" r="7" />
    <path d="M21 21l-4.3-4.3" />
  </svg>
)

export const XIcon = (props: IconProps) => (
  <svg {...base} {...props}>
    <path d="M18 6L6 18M6 6l12 12" />
  </svg>
)

export const BoltIcon = (props: IconProps) => (
  <svg {...base} fill="currentColor" stroke="none" viewBox="0 0 24 24" {...props}>
    <path d="M13.5 2L4 14h6l-1 8 9.5-12h-6l1-8z" />
  </svg>
)

export const ZapOffIcon = (props: IconProps) => (
  <svg {...base} {...props}>
    <path d="M12.41 6.75L13 2l-2.43 2.92" />
    <path d="M18.57 12.91L21 10h-6l1-4" />
    <path d="M8 8l-6 7h6l-1 8 5.94-7.11" />
    <path d="M2 2l20 20" />
  </svg>
)

export const ChevronRightIcon = (props: IconProps) => (
  <svg {...base} {...props}>
    <path d="M9 18l6-6-6-6" />
  </svg>
)
