"use client"

import { useState, useEffect } from "react"
import { getUnreadCount } from "@/lib/api/notifications"

export function useNotificationCount() {
  const [count, setCount] = useState(0)

  useEffect(() => {
    let mounted = true

    async function fetchCount() {
      try {
        const res = await getUnreadCount()
        if (mounted && res.success) {
          setCount(res.data.count)
        }
      } catch {
        // silently fail
      }
    }

    fetchCount()
    const interval = setInterval(fetchCount, 30000) // poll every 30s

    return () => {
      mounted = false
      clearInterval(interval)
    }
  }, [])

  return count
}
