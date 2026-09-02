import type { Contact, ApiResponse } from "@/lib/types";
import { USE_MOCK, apiRequest, mockDelay, mockResponse } from "./client";
import { mockContacts } from "@/lib/mock/data";

export async function getContacts(search?: string): Promise<ApiResponse<Contact[]>> {
  if (USE_MOCK) {
    await mockDelay(300);
    let contacts = [...mockContacts];
    if (search) {
      const s = search.toLowerCase();
      contacts = contacts.filter((c) => c.name.toLowerCase().includes(s) || c.phone.includes(s) || c.email?.toLowerCase().includes(s));
    }
    contacts.sort((a, b) => a.name.localeCompare(b.name));
    return mockResponse(contacts);
  }
  const params = search ? `?search=${encodeURIComponent(search)}` : "";
  return apiRequest<Contact[]>(`/contacts${params}`);
}

export async function getContact(id: string): Promise<ApiResponse<Contact>> {
  if (USE_MOCK) {
    await mockDelay(200);
    const contact = mockContacts.find((c) => c.id === id);
    if (!contact) return { success: false, data: {} as Contact, message: "Contact not found" };
    return mockResponse(contact);
  }
  return apiRequest<Contact>(`/contacts/${id}`);
}

export async function createContact(data: Partial<Contact>): Promise<ApiResponse<Contact>> {
  if (USE_MOCK) {
    await mockDelay(400);
    const newContact: Contact = {
      id: "c" + Date.now(),
      name: data.name || "",
      phone: data.phone || "",
      whatsappNumber: data.whatsappNumber,
      email: data.email,
      bankDetails: data.bankDetails || [],
      upiIds: data.upiIds || [],
      avatar: data.avatar,
      createdAt: new Date().toISOString(),
    };
    mockContacts.push(newContact);
    return mockResponse(newContact, "Contact created");
  }
  return apiRequest<Contact>("/contacts", { method: "POST", body: JSON.stringify(data) });
}

export async function updateContact(id: string, data: Partial<Contact>): Promise<ApiResponse<Contact>> {
  if (USE_MOCK) {
    await mockDelay(300);
    const idx = mockContacts.findIndex((c) => c.id === id);
    if (idx === -1) return { success: false, data: {} as Contact, message: "Not found" };
    mockContacts[idx] = { ...mockContacts[idx], ...data };
    return mockResponse(mockContacts[idx], "Contact updated");
  }
  return apiRequest<Contact>(`/contacts/${id}`, { method: "PUT", body: JSON.stringify(data) });
}

export async function deleteContact(id: string): Promise<ApiResponse<{ message: string }>> {
  if (USE_MOCK) {
    await mockDelay(300);
    const idx = mockContacts.findIndex((c) => c.id === id);
    if (idx !== -1) mockContacts.splice(idx, 1);
    return mockResponse({ message: "Contact deleted" });
  }
  return apiRequest(`/contacts/${id}`, { method: "DELETE" });
}
