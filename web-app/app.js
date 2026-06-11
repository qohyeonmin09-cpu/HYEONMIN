const weekdays = [
  { id: 2, title: "월", names: ["월", "월요일", "mon"] },
  { id: 3, title: "화", names: ["화", "화요일", "tue"] },
  { id: 4, title: "수", names: ["수", "수요일", "wed"] },
  { id: 5, title: "목", names: ["목", "목요일", "thu"] },
  { id: 6, title: "금", names: ["금", "금요일", "fri"] }
];

const defaultData = {
  version: 2,
  periods: makePeriods(9 * 60, 50, 60, 7, 4, 13 * 60 + 10),
  entries: [],
  preference: { enabled: true, leadMinutes: 5 }
};

let data = loadData();
let selectedWeekday = 2;
let timers = [];
let pendingTimeTarget = null;
let customStartMinutes = 9 * 60;
let customEndMinutes = 9 * 60 + 50;
let selectedImageFile = null;

const els = {
  nextClassText: document.querySelector("#nextClassText"),
  notifyButton: document.querySelector("#notifyButton"),
  tabs: document.querySelectorAll(".tab"),
  panels: document.querySelectorAll(".panel"),
  todayList: document.querySelector("#todayList"),
  weekdayTabs: document.querySelector("#weekdayTabs"),
  scheduleList: document.querySelector("#scheduleList"),
  periodList: document.querySelector("#periodList"),
  addEntryButton: document.querySelector("#addEntryButton"),
  firstStartButton: document.querySelector("#firstStartButton"),
  afterLunchStartButton: document.querySelector("#afterLunchStartButton"),
  classLength: document.querySelector("#classLength"),
  periodInterval: document.querySelector("#periodInterval"),
  periodCount: document.querySelector("#periodCount"),
  applyQuickSetupButton: document.querySelector("#applyQuickSetupButton"),
  imageInput: document.querySelector("#imageInput"),
  imagePreview: document.querySelector("#imagePreview"),
  runOcrButton: document.querySelector("#runOcrButton"),
  ocrStatus: document.querySelector("#ocrStatus"),
  importText: document.querySelector("#importText"),
  parseImportButton: document.querySelector("#parseImportButton"),
  importCandidates: document.querySelector("#importCandidates"),
  leadMinutes: document.querySelector("#leadMinutes"),
  notificationsEnabled: document.querySelector("#notificationsEnabled"),
  notificationStatus: document.querySelector("#notificationStatus"),
  entryDialog: document.querySelector("#entryDialog"),
  entryForm: document.querySelector("#entryForm"),
  entryDialogTitle: document.querySelector("#entryDialogTitle"),
  entryId: document.querySelector("#entryId"),
  subjectName: document.querySelector("#subjectName"),
  entryWeekday: document.querySelector("#entryWeekday"),
  entryTimeMode: document.querySelector("#entryTimeMode"),
  periodSelectRow: document.querySelector("#periodSelectRow"),
  entryPeriod: document.querySelector("#entryPeriod"),
  customTimeRow: document.querySelector("#customTimeRow"),
  customStartButton: document.querySelector("#customStartButton"),
  customEndButton: document.querySelector("#customEndButton"),
  deleteEntryButton: document.querySelector("#deleteEntryButton"),
  cancelEntryButton: document.querySelector("#cancelEntryButton"),
  timeDialog: document.querySelector("#timeDialog"),
  timeDialDisplay: document.querySelector("#timeDialDisplay"),
  dialHour: document.querySelector("#dialHour"),
  dialMinute: document.querySelector("#dialMinute"),
  cancelTimeButton: document.querySelector("#cancelTimeButton"),
  saveTimeButton: document.querySelector("#saveTimeButton"),
  quickTimes: document.querySelectorAll(".quick-time")
};

init();

function init() {
  bindEvents();
  renderAll();
  scheduleNotifications();
  setInterval(renderToday, 60_000);
}

function bindEvents() {
  els.tabs.forEach((button) => button.addEventListener("click", () => showTab(button.dataset.tab)));
  els.notifyButton.addEventListener("click", requestNotificationPermission);
  els.addEntryButton.addEventListener("click", () => openEntryDialog());
  els.firstStartButton.addEventListener("click", () => openTimeDial(parseTime(els.firstStartButton.textContent), (minutes) => {
    els.firstStartButton.textContent = formatTime(minutes);
  }));
  els.afterLunchStartButton.addEventListener("click", () => openTimeDial(parseTime(els.afterLunchStartButton.textContent), (minutes) => {
    els.afterLunchStartButton.textContent = formatTime(minutes);
  }));
  els.applyQuickSetupButton.addEventListener("click", applyQuickSetup);
  els.parseImportButton.addEventListener("click", renderImportCandidates);
  els.runOcrButton.addEventListener("click", runOCR);
  els.imageInput.addEventListener("change", handleImageChange);
  els.leadMinutes.addEventListener("input", updatePreference);
  els.notificationsEnabled.addEventListener("change", updatePreference);
  els.entryTimeMode.addEventListener("change", syncEntryTimeMode);
  els.cancelEntryButton.addEventListener("click", () => els.entryDialog.close());
  els.deleteEntryButton.addEventListener("click", deleteCurrentEntry);
  els.entryForm.addEventListener("submit", saveEntryFromDialog);
  els.customStartButton.addEventListener("click", () => openTimeDial(customStartMinutes, (minutes) => {
    customStartMinutes = minutes;
    if (customEndMinutes < customStartMinutes) customEndMinutes = customStartMinutes + 50;
    syncCustomTimeButtons();
  }));
  els.customEndButton.addEventListener("click", () => openTimeDial(customEndMinutes, (minutes) => {
    customEndMinutes = Math.max(minutes, customStartMinutes);
    syncCustomTimeButtons();
  }));
  els.dialHour.addEventListener("input", renderTimeDial);
  els.dialMinute.addEventListener("input", renderTimeDial);
  els.cancelTimeButton.addEventListener("click", () => els.timeDialog.close());
  els.saveTimeButton.addEventListener("click", saveTimeDial);
  els.quickTimes.forEach((button) => button.addEventListener("click", () => setDialTime(parseTime(button.dataset.time))));
}

function showTab(tabName) {
  els.tabs.forEach((button) => button.classList.toggle("active", button.dataset.tab === tabName));
  els.panels.forEach((panel) => panel.classList.toggle("active", panel.id === tabName));
}

function renderAll() {
  renderWeekdayTabs();
  renderToday();
  renderSchedule();
  renderPeriods();
  renderSettings();
  renderEntryOptions();
}

function renderWeekdayTabs() {
  els.weekdayTabs.innerHTML = "";
  weekdays.forEach((weekday) => {
    const button = document.createElement("button");
    button.className = `weekday-tab${weekday.id === selectedWeekday ? " active" : ""}`;
    button.textContent = weekday.title;
    button.addEventListener("click", () => {
      selectedWeekday = weekday.id;
      renderWeekdayTabs();
      renderSchedule();
    });
    els.weekdayTabs.append(button);
  });
}

function renderToday() {
  const today = new Date().getDay() + 1;
  const now = minutesFromDate(new Date());
  const entries = sortedEntries().filter((entry) => entry.weekday === today && getEndMinutes(entry) >= now);

  els.todayList.innerHTML = "";
  if (entries.length === 0) {
    els.todayList.append(empty("오늘 남은 수업이 없어요."));
    els.nextClassText.textContent = "다음 수업이 없습니다";
    return;
  }

  entries.forEach((entry) => els.todayList.append(entryCard(entry)));
  const next = entries[0];
  els.nextClassText.textContent = `다음 수업: ${next.subjectName} ${formatTime(getStartMinutes(next))}`;
}

function renderSchedule() {
  const entries = sortedEntries().filter((entry) => entry.weekday === selectedWeekday);
  els.scheduleList.innerHTML = "";

  if (entries.length === 0) {
    els.scheduleList.append(empty("등록된 수업이 없어요. + 버튼 또는 사진 인식으로 추가하세요."));
    return;
  }

  entries.forEach((entry) => {
    const card = entryCard(entry);
    card.addEventListener("click", () => openEntryDialog(entry));
    els.scheduleList.append(card);
  });
}

function renderPeriods() {
  els.periodList.innerHTML = "";
  sortedPeriods().forEach((period) => {
    const row = document.createElement("div");
    row.className = "item period-row";

    const title = document.createElement("strong");
    title.textContent = `${period.periodNumber}교시`;

    const startButton = document.createElement("button");
    startButton.className = "time-button";
    startButton.type = "button";
    startButton.textContent = formatTime(period.startMinutes);
    startButton.addEventListener("click", () => openTimeDial(period.startMinutes, (minutes) => {
      period.startMinutes = minutes;
      if (period.endMinutes < period.startMinutes) period.endMinutes = period.startMinutes + Number(els.classLength.value || 50);
      saveAndRender();
    }));

    const endButton = document.createElement("button");
    endButton.className = "time-button";
    endButton.type = "button";
    endButton.textContent = formatTime(period.endMinutes);
    endButton.addEventListener("click", () => openTimeDial(period.endMinutes, (minutes) => {
      period.endMinutes = Math.max(minutes, period.startMinutes);
      saveAndRender();
    }));

    const deleteButton = document.createElement("button");
    deleteButton.className = "danger";
    deleteButton.type = "button";
    deleteButton.textContent = "삭제";
    deleteButton.addEventListener("click", () => deletePeriod(period.id));

    row.append(title, startButton, endButton, deleteButton);
    els.periodList.append(row);
  });
}

function renderSettings() {
  els.leadMinutes.value = data.preference.leadMinutes;
  els.notificationsEnabled.checked = data.preference.enabled;
  els.notificationStatus.textContent = notificationStatusText();
}

function renderEntryOptions() {
  els.entryWeekday.innerHTML = weekdays.map((weekday) => `<option value="${weekday.id}">${weekday.title}</option>`).join("");
  els.entryPeriod.innerHTML = sortedPeriods()
    .map((period) => `<option value="${period.id}">${period.periodNumber}교시 ${formatTime(period.startMinutes)}-${formatTime(period.endMinutes)}</option>`)
    .join("");
}

function applyQuickSetup() {
  const firstStart = parseTime(els.firstStartButton.textContent);
  const afterLunchStart = parseTime(els.afterLunchStartButton.textContent);
  const classLength = clamp(Number(els.classLength.value || 50), 10, 120);
  const interval = clamp(Number(els.periodInterval.value || 60), classLength, 180);
  const count = clamp(Number(els.periodCount.value || 7), 1, 12);
  const oldPeriodNumbers = new Map(data.periods.map((period) => [period.id, period.periodNumber]));

  data.periods = makePeriods(firstStart, classLength, interval, count, 4, afterLunchStart);
  data.entries = data.entries.map((entry) => {
    if (entry.timeMode !== "period") return entry;
    const periodNumber = oldPeriodNumbers.get(entry.periodId) ?? 1;
    return { ...entry, periodId: data.periods[Math.min(periodNumber - 1, data.periods.length - 1)]?.id ?? null };
  });
  saveAndRender();
}

function makePeriods(firstStart, classLength, interval, count, lunchAfterPeriod = 4, afterLunchStart = 13 * 60 + 10) {
  return Array.from({ length: count }, (_, index) => {
    const start = index < lunchAfterPeriod
      ? firstStart + interval * index
      : afterLunchStart + interval * (index - lunchAfterPeriod);
    return {
      id: crypto.randomUUID(),
      periodNumber: index + 1,
      startMinutes: start,
      endMinutes: Math.min(start + classLength, 23 * 60 + 59)
    };
  });
}

function handleImageChange(event) {
  selectedImageFile = event.target.files?.[0] ?? null;
  if (!selectedImageFile) {
    els.imagePreview.hidden = true;
    return;
  }

  els.imagePreview.src = URL.createObjectURL(selectedImageFile);
  els.imagePreview.hidden = false;
  els.ocrStatus.textContent = "사진이 선택되었습니다. 사진에서 글자 읽기를 누르세요.";
}

async function runOCR() {
  if (!selectedImageFile) {
    els.ocrStatus.textContent = "먼저 시간표 사진을 선택하세요.";
    return;
  }

  if (!window.Tesseract) {
    els.ocrStatus.textContent = "OCR 라이브러리를 불러오지 못했습니다. 텍스트를 직접 붙여넣어 후보를 만들 수 있습니다.";
    return;
  }

  els.ocrStatus.textContent = "사진을 읽는 중입니다. 처음 실행은 조금 걸릴 수 있어요.";
  els.runOcrButton.disabled = true;

  try {
    const result = await Tesseract.recognize(selectedImageFile, "kor+eng", {
      logger: (message) => {
        if (message.status === "recognizing text") {
          els.ocrStatus.textContent = `글자 인식 중 ${Math.round((message.progress || 0) * 100)}%`;
        }
      }
    });
    els.importText.value = result.data.text.trim();
    els.ocrStatus.textContent = "인식 완료. 후보 만들기를 눌러 확인하세요.";
  } catch (error) {
    els.ocrStatus.textContent = "사진 인식에 실패했습니다. 텍스트를 직접 붙여넣어 진행하세요.";
  } finally {
    els.runOcrButton.disabled = false;
  }
}

function renderImportCandidates() {
  const candidates = parseImportText(els.importText.value);
  els.importCandidates.innerHTML = "";

  if (candidates.length === 0) {
    els.importCandidates.append(empty("후보를 찾지 못했어요. 예: '월 1교시 수학' 또는 '화 09:00 과학'처럼 적어보세요."));
    return;
  }

  candidates.forEach((entry) => els.importCandidates.append(entryCard(entry)));

  const button = document.createElement("button");
  button.className = "primary";
  button.textContent = "후보를 시간표에 추가";
  button.addEventListener("click", () => {
    data.entries.push(...candidates);
    saveAndRender();
    els.importCandidates.innerHTML = "";
    els.importText.value = "";
    showTab("schedule");
  });
  els.importCandidates.append(button);
}

function parseImportText(text) {
  const result = [];
  const lines = text.split(/\r?\n/).map((line) => line.trim()).filter(Boolean);
  let currentWeekday = null;

  for (const line of lines) {
    currentWeekday = findWeekday(line) ?? currentWeekday;
    const periodNumber = Number(line.match(/([1-9]|1[0-2])\s*(교시|period)/i)?.[1] ?? "");
    const explicitTime = line.match(/(\d{1,2})[:：](\d{2})/);
    const subjectName = cleanSubjectName(line);

    if (!currentWeekday || !subjectName) continue;

    if (explicitTime) {
      const start = Number(explicitTime[1]) * 60 + Number(explicitTime[2]);
      result.push({
        id: crypto.randomUUID(),
        weekday: currentWeekday.id,
        subjectName,
        timeMode: "custom",
        periodId: null,
        customStartMinutes: start,
        customEndMinutes: start + Number(els.classLength.value || 50)
      });
      continue;
    }

    const period = data.periods.find((item) => item.periodNumber === periodNumber) ?? data.periods[periodNumber - 1] ?? sortedPeriods()[0];
    if (!period) continue;

    result.push({
      id: crypto.randomUUID(),
      weekday: currentWeekday.id,
      subjectName,
      timeMode: "period",
      periodId: period.id,
      customStartMinutes: null,
      customEndMinutes: null
    });
  }

  return result;
}

function findWeekday(text) {
  const lowered = text.toLowerCase();
  return weekdays.find((weekday) => weekday.names.some((name) => lowered.includes(name)));
}

function cleanSubjectName(line) {
  return line
    .replace(/월요일|화요일|수요일|목요일|금요일|월|화|수|목|금/gi, " ")
    .replace(/([1-9]|1[0-2])\s*(교시|period)/gi, " ")
    .replace(/\d{1,2}[:：]\d{2}/g, " ")
    .replace(/\b(mon|tue|wed|thu|fri|monday|tuesday|wednesday|thursday|friday)\b/gi, " ")
    .replace(/시간표|timetable|schedule/gi, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function openEntryDialog(entry = null) {
  const firstPeriod = sortedPeriods()[0];
  const draft = entry ?? {
    id: "",
    weekday: selectedWeekday,
    subjectName: "",
    timeMode: firstPeriod ? "period" : "custom",
    periodId: firstPeriod?.id ?? "",
    customStartMinutes: 9 * 60,
    customEndMinutes: 9 * 60 + 50
  };

  customStartMinutes = draft.customStartMinutes ?? getStartMinutes(draft) ?? 9 * 60;
  customEndMinutes = draft.customEndMinutes ?? getEndMinutes(draft) ?? customStartMinutes + 50;
  els.entryDialogTitle.textContent = entry ? "수업 수정" : "수업 추가";
  els.entryId.value = draft.id;
  els.subjectName.value = draft.subjectName;
  els.entryWeekday.value = draft.weekday;
  els.entryTimeMode.value = draft.timeMode;
  els.entryPeriod.value = draft.periodId ?? firstPeriod?.id ?? "";
  els.deleteEntryButton.style.visibility = entry ? "visible" : "hidden";
  syncCustomTimeButtons();
  syncEntryTimeMode();
  els.entryDialog.showModal();
}

function syncEntryTimeMode() {
  const isPeriod = els.entryTimeMode.value === "period" && data.periods.length > 0;
  els.periodSelectRow.style.display = isPeriod ? "grid" : "none";
  els.customTimeRow.style.display = isPeriod ? "none" : "grid";
}

function syncCustomTimeButtons() {
  els.customStartButton.textContent = formatTime(customStartMinutes);
  els.customEndButton.textContent = formatTime(customEndMinutes);
}

function saveEntryFromDialog(event) {
  event.preventDefault();
  const id = els.entryId.value || crypto.randomUUID();
  const timeMode = data.periods.length > 0 ? els.entryTimeMode.value : "custom";
  const entry = {
    id,
    weekday: Number(els.entryWeekday.value),
    subjectName: els.subjectName.value.trim(),
    timeMode,
    periodId: timeMode === "period" ? els.entryPeriod.value : null,
    customStartMinutes: timeMode === "custom" ? customStartMinutes : null,
    customEndMinutes: timeMode === "custom" ? Math.max(customEndMinutes, customStartMinutes) : null
  };

  const index = data.entries.findIndex((item) => item.id === id);
  if (index >= 0) data.entries[index] = entry;
  else data.entries.push(entry);

  selectedWeekday = entry.weekday;
  els.entryDialog.close();
  saveAndRender();
}

function deleteCurrentEntry() {
  data.entries = data.entries.filter((entry) => entry.id !== els.entryId.value);
  els.entryDialog.close();
  saveAndRender();
}

function deletePeriod(periodId) {
  const period = data.periods.find((item) => item.id === periodId);
  if (!period) return;

  data.entries = data.entries.map((entry) => {
    if (entry.periodId !== periodId) return entry;
    return {
      ...entry,
      timeMode: "custom",
      periodId: null,
      customStartMinutes: period.startMinutes,
      customEndMinutes: period.endMinutes
    };
  });
  data.periods = data.periods.filter((item) => item.id !== periodId);
  saveAndRender();
}

function openTimeDial(initialMinutes, onSave) {
  pendingTimeTarget = onSave;
  setDialTime(initialMinutes);
  els.timeDialog.showModal();
}

function setDialTime(minutes) {
  els.dialHour.value = Math.floor(minutes / 60);
  els.dialMinute.value = Math.round((minutes % 60) / 5) * 5;
  renderTimeDial();
}

function renderTimeDial() {
  els.timeDialDisplay.textContent = formatTime(Number(els.dialHour.value) * 60 + Number(els.dialMinute.value));
}

function saveTimeDial() {
  if (pendingTimeTarget) pendingTimeTarget(Number(els.dialHour.value) * 60 + Number(els.dialMinute.value));
  els.timeDialog.close();
}

function updatePreference() {
  data.preference.leadMinutes = clamp(Number(els.leadMinutes.value || 5), 1, 60);
  data.preference.enabled = els.notificationsEnabled.checked;
  saveAndRender();
}

async function requestNotificationPermission() {
  if (!("Notification" in window)) {
    renderSettings();
    return;
  }
  await Notification.requestPermission();
  data.preference.enabled = Notification.permission === "granted";
  saveAndRender();
}

function scheduleNotifications() {
  timers.forEach(clearTimeout);
  timers = [];

  if (!data.preference.enabled || !("Notification" in window) || Notification.permission !== "granted") return;

  data.entries.forEach((entry) => {
    const delay = nextDelayForEntry(entry);
    if (delay == null) return;

    const timer = setTimeout(() => {
      new Notification(`곧 ${entry.subjectName} 시간이에요`, {
        body: `${data.preference.leadMinutes}분 후 수업이 시작됩니다.`
      });
      scheduleNotifications();
    }, delay);
    timers.push(timer);
  });
}

function nextDelayForEntry(entry) {
  const start = getStartMinutes(entry);
  if (start == null) return null;

  const now = new Date();
  const target = new Date(now);
  const targetDay = entry.weekday - 1;
  const dayDelta = (targetDay - now.getDay() + 7) % 7;
  const alertMinutes = (start - data.preference.leadMinutes + 1440) % 1440;

  target.setDate(now.getDate() + dayDelta);
  target.setHours(Math.floor(alertMinutes / 60), alertMinutes % 60, 0, 0);
  if (target <= now) target.setDate(target.getDate() + 7);
  return target.getTime() - now.getTime();
}

function entryCard(entry) {
  const card = document.createElement("button");
  card.type = "button";
  card.className = "item";
  card.innerHTML = `
    <div>
      <strong>${escapeHtml(entry.subjectName)}</strong>
      <span>${weekdayTitle(entry.weekday)} · ${entryTimeText(entry)}</span>
    </div>
    <span>${entry.timeMode === "period" ? "교시" : "직접"}</span>
  `;
  return card;
}

function empty(text) {
  const element = document.createElement("p");
  element.className = "empty";
  element.textContent = text;
  return element;
}

function entryTimeText(entry) {
  const period = data.periods.find((item) => item.id === entry.periodId);
  const prefix = period && entry.timeMode === "period" ? `${period.periodNumber}교시 · ` : "";
  return `${prefix}${formatTime(getStartMinutes(entry))}-${formatTime(getEndMinutes(entry))}`;
}

function getStartMinutes(entry) {
  if (entry.timeMode === "custom") return entry.customStartMinutes;
  return data.periods.find((period) => period.id === entry.periodId)?.startMinutes ?? null;
}

function getEndMinutes(entry) {
  if (entry.timeMode === "custom") return entry.customEndMinutes;
  return data.periods.find((period) => period.id === entry.periodId)?.endMinutes ?? null;
}

function sortedEntries() {
  return [...data.entries].sort((a, b) => {
    if (a.weekday !== b.weekday) return a.weekday - b.weekday;
    return (getStartMinutes(a) ?? 9999) - (getStartMinutes(b) ?? 9999);
  });
}

function sortedPeriods() {
  return [...data.periods].sort((a, b) => a.periodNumber - b.periodNumber);
}

function saveAndRender() {
  saveData();
  renderAll();
  scheduleNotifications();
}

function loadData() {
  const saved = localStorage.getItem("timeTableAlarmData");
  if (!saved) return structuredClone(defaultData);
  try {
    const parsed = JSON.parse(saved);
    if ((parsed.version ?? 1) < 2 && (!parsed.entries || parsed.entries.length === 0)) {
      return structuredClone(defaultData);
    }

    return {
      version: defaultData.version,
      periods: Array.isArray(parsed.periods) ? parsed.periods : structuredClone(defaultData.periods),
      entries: Array.isArray(parsed.entries) ? parsed.entries : [],
      preference: { ...defaultData.preference, ...(parsed.preference ?? {}) }
    };
  } catch {
    return structuredClone(defaultData);
  }
}

function saveData() {
  data.version = defaultData.version;
  localStorage.setItem("timeTableAlarmData", JSON.stringify(data));
}

function formatTime(minutes) {
  if (minutes == null || Number.isNaN(minutes)) return "--:--";
  const wrapped = ((minutes % 1440) + 1440) % 1440;
  const hour = String(Math.floor(wrapped / 60)).padStart(2, "0");
  const minute = String(wrapped % 60).padStart(2, "0");
  return `${hour}:${minute}`;
}

function parseTime(value) {
  const [hour, minute] = String(value).split(":").map(Number);
  return (hour || 0) * 60 + (minute || 0);
}

function minutesFromDate(date) {
  return date.getHours() * 60 + date.getMinutes();
}

function weekdayTitle(id) {
  return weekdays.find((weekday) => weekday.id === id)?.title ?? "";
}

function notificationStatusText() {
  if (!("Notification" in window)) return "이 브라우저는 알림을 지원하지 않습니다.";
  if (Notification.permission === "granted") return "알림 권한이 허용되었습니다.";
  if (Notification.permission === "denied") return "브라우저에서 알림 권한이 차단되었습니다.";
  return "알림 권한이 아직 설정되지 않았습니다.";
}

function clamp(value, min, max) {
  return Math.min(Math.max(value, min), max);
}

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (char) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#039;"
  })[char]);
}
