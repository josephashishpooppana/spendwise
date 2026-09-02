import type {
  AnalyticsOverview, MethodBreakdown, CategoryBreakdown,
  CashbackAnalytics, TrendDataPoint, SmartSuggestion, PeriodComparison, AnalyticsFilters, ApiResponse,
} from "@/lib/types";
import { USE_MOCK, apiRequest, mockDelay, mockResponse } from "./client";
import {
  mockAnalyticsOverview, mockMethodBreakdowns, mockCategoryBreakdowns,
  mockCashbackAnalytics, mockTrendData, mockSmartSuggestions, mockPeriodComparison,
} from "@/lib/mock/data";

export async function getAnalyticsOverview(filters?: AnalyticsFilters): Promise<ApiResponse<AnalyticsOverview>> {
  if (USE_MOCK) {
    await mockDelay(300);
    return mockResponse(mockAnalyticsOverview);
  }
  const params = new URLSearchParams();
  if (filters) Object.entries(filters).forEach(([k, v]) => { if (v) params.append(k, String(v)); });
  return apiRequest<AnalyticsOverview>(`/analytics/overview?${params.toString()}`);
}

export async function getMethodBreakdowns(filters?: AnalyticsFilters): Promise<ApiResponse<MethodBreakdown[]>> {
  if (USE_MOCK) {
    await mockDelay(300);
    return mockResponse(mockMethodBreakdowns);
  }
  const params = new URLSearchParams();
  if (filters) Object.entries(filters).forEach(([k, v]) => { if (v) params.append(k, String(v)); });
  return apiRequest<MethodBreakdown[]>(`/analytics/methods?${params.toString()}`);
}

export async function getCategoryBreakdowns(filters?: AnalyticsFilters): Promise<ApiResponse<CategoryBreakdown[]>> {
  if (USE_MOCK) {
    await mockDelay(300);
    return mockResponse(mockCategoryBreakdowns);
  }
  const params = new URLSearchParams();
  if (filters) Object.entries(filters).forEach(([k, v]) => { if (v) params.append(k, String(v)); });
  return apiRequest<CategoryBreakdown[]>(`/analytics/categories?${params.toString()}`);
}

export async function getCashbackAnalytics(filters?: AnalyticsFilters): Promise<ApiResponse<CashbackAnalytics>> {
  if (USE_MOCK) {
    await mockDelay(300);
    return mockResponse(mockCashbackAnalytics);
  }
  const params = new URLSearchParams();
  if (filters) Object.entries(filters).forEach(([k, v]) => { if (v) params.append(k, String(v)); });
  return apiRequest<CashbackAnalytics>(`/analytics/cashback?${params.toString()}`);
}

export async function getTrendData(filters?: AnalyticsFilters): Promise<ApiResponse<TrendDataPoint[]>> {
  if (USE_MOCK) {
    await mockDelay(300);
    return mockResponse(mockTrendData);
  }
  const params = new URLSearchParams();
  if (filters) Object.entries(filters).forEach(([k, v]) => { if (v) params.append(k, String(v)); });
  return apiRequest<TrendDataPoint[]>(`/analytics/trends?${params.toString()}`);
}

export async function getSmartSuggestions(): Promise<ApiResponse<SmartSuggestion[]>> {
  if (USE_MOCK) {
    await mockDelay(300);
    return mockResponse(mockSmartSuggestions);
  }
  return apiRequest<SmartSuggestion[]>("/analytics/suggestions");
}

export async function getPeriodComparison(filters?: AnalyticsFilters): Promise<ApiResponse<PeriodComparison>> {
  if (USE_MOCK) {
    await mockDelay(300);
    return mockResponse(mockPeriodComparison);
  }
  const params = new URLSearchParams();
  if (filters) Object.entries(filters).forEach(([k, v]) => { if (v) params.append(k, String(v)); });
  return apiRequest<PeriodComparison>(`/analytics/comparison?${params.toString()}`);
}
