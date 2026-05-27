const NATIVE_HOST = "com.claude.usage";

async function fetchAndSend() {
  try {
    // Auto-detect org ID from the lastActiveOrg cookie — works for any user
    const cookie = await chrome.cookies.get({
      url: "https://claude.ai",
      name: "lastActiveOrg"
    });

    if (!cookie) {
      console.warn("Claude Usage Tracker: not logged into claude.ai, skipping fetch.");
      return;
    }

    const orgId = cookie.value;
    const response = await fetch(`https://claude.ai/api/organizations/${orgId}/usage`);

    if (!response.ok) {
      console.error(`Claude Usage Tracker: API error ${response.status}`);
      return;
    }

    const data = await response.json();
    data._fetched_at = new Date().toISOString();

    chrome.runtime.sendNativeMessage(NATIVE_HOST, data, () => {
      if (chrome.runtime.lastError) {
        console.error("Claude Usage Tracker: native messaging error —", chrome.runtime.lastError.message);
      }
    });
  } catch (e) {
    console.error("Claude Usage Tracker: fetch failed —", e);
  }
}

chrome.runtime.onInstalled.addListener(fetchAndSend);
chrome.runtime.onStartup.addListener(fetchAndSend);

chrome.alarms.create("refresh", { periodInMinutes: 5 });
chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === "refresh") fetchAndSend();
});
