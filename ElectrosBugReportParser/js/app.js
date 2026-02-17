import '@knadh/oat/oat.min.css';
import '@knadh/oat/oat.min.js';


document.addEventListener('DOMContentLoaded', () => {
  document.querySelector("#bugReportImport").addEventListener("change", (e) => {
    const fileData = e.target.files[0];

    if (!fileData) {
      return;
    }

    handleReport(fileData);
  });

  document.querySelector("#navbar").querySelectorAll("[data-page]").forEach((element) => {
    element.addEventListener("click", (e) => {
      navigate(element.dataset.page);
    });
  });
});

function navigate(page) {
  document.querySelector("main").querySelectorAll("[data-page]").forEach((element) => {
    if (element.dataset.page === page) {
      element.style.display = "block";
    } else {
      element.style.display = "none";
    }
  });

  document.querySelector("#navbar").querySelectorAll("[data-page]").forEach((element) => {
    if (element.dataset.page === page) {
      element.ariaCurrent = "page";
    } else {
      element.ariaCurrent = null;
    }
  });
}


/**
 *
 * @param {!File} file
 */
function handleReport(file) {
  decompressFile(file).then((result) => {
    const content = JSON.parse(result);

    document.getElementById("platform").innerText = content.platform;
    document.getElementById("version").innerText = content.verison;

    pushNetworkRequests(content.networkLogs);
    pushConsoleLogs(content.consoleLogs);
  }).catch((e) => {

  });
}


function pushConsoleLogs(logs) {
  const table = document.getElementById("consoleTable").tBodies[0];
  table.innerHTML = "";

  logs.forEach((log) => {
    const tr = document.createElement("tr");

    const date = new Date(log.timestamp).toLocaleString();

    tr.innerHTML = `
    <td>${log.level}</td>
    <td>${date}</td>
    <td>${log.args}</td>
    `;

    table.appendChild(tr);
  });
}


/**
 *
 * @param {Array<Object>} networkLogs
 */
function pushNetworkRequests(networkLogs) {
  const table = document.querySelector("#requestsTable").tBodies[0];
  table.innerHTML = "";

  networkLogs.forEach(log => {
    const row = document.createElement("tr");

    const datetimeSentAt = new Date(log.timestamp).toLocaleString();

    let datetimeReceivedAt = "No Response";

    if (log.endTimestamp !== null && log.endTimestamp !== undefined) {
      datetimeReceivedAt = new Date(log.endTimestamp).toLocaleString();
    }

    let methodBadgeClass = "outline";
    let statusBadgeClass = "outline";

    if (log.status >= 200 && log.status < 300) {
      statusBadgeClass = "success";
    } else if (log.status >= 300 && log.status < 400) {
      statusBadgeClass = "secondary";
    } else if (log.status >= 400 && log.status < 500) {
      statusBadgeClass = "warning";
    } else if (log.status >= 500 && log.status < 600) {
      statusBadgeClass = "danger";
    }

    row.innerHTML = `
    <td>${log.url}</td>
    <td>
        <span class="badge ${methodBadgeClass}">${log.method}</span>
    </td>
    <td>
        <span class="badge ${statusBadgeClass}">${log.status}</span>
    </td>
    <td>${datetimeSentAt}</td>
    <td>${datetimeReceivedAt}</td>
    `;

    row.addEventListener("click", (e) => {
      openNetDialog(log);
    });

    table.appendChild(row);
  });
}


/**
 *
 * @param {Object} log
 */
function openNetDialog(log) {
  const dialog = document.getElementById("networkRequest");

  dialog.querySelector("#dialogUrl").innerText = log.url;
  dialog.querySelector("#dialogMethod").innerText = log.method;
  dialog.querySelector("#dialogStatus").innerText = log.status;
  dialog.querySelector("#dialogReqBody").innerText = JSON.stringify(log.body);

  const startTs = new Date(log.timestamp);
  const datetimeSentAt = startTs.toLocaleString();

  let datetimeReceivedAt = "No Response";
  let duration = "";

  if (log.endTimestamp !== null && log.endTimestamp !== undefined) {
    const endTs = new Date(log.endTimestamp);
    datetimeReceivedAt = endTs.toLocaleString();
    duration = formatDuration(startTs, endTs);
  }

  dialog.querySelector("#dialogStart").innerText = datetimeSentAt;
  dialog.querySelector("#dialogEnd").innerText = datetimeReceivedAt;
  dialog.querySelector("#dialogDuration").innerText = duration;

  if (log.responseBody !== undefined && log.responseBody !== null) {
    let content = "";

    if (typeof(log.responseBody) === "string") {
      content = log.responseBody;
    } else {
      content = JSON.stringify(log.responseBody, null, 2);
    }

    dialog.querySelector("#dialogResBody").innerText = content;
  }

  const reqHeadersTable = dialog.querySelector("#requestHeadersTable");
  const resHeadersTable = dialog.querySelector("#responseHeadersTable");

  reqHeadersTable.innerHTML = "";
  resHeadersTable.innerHTML = "";

  Object.entries(log.headers).forEach((entry) => {
    const tr = document.createElement("tr");
    tr.innerHTML = `<td>${entry[0]}</td><td>${entry[1]}</td>`;
    reqHeadersTable.appendChild(tr);
  });

  if (log.responseHeaders !== undefined && log.responseHeaders !== null) {
    Object.entries(log.responseHeaders).forEach((entry) => {
      const tr = document.createElement("tr");
      tr.innerHTML = `<td>${entry[0]}</td><td>${entry[1]}</td>`;
      reqHeadersTable.appendChild(tr);
    });
  }

  dialog.showModal();
}


function formatDuration(startTs, endTs) {
  let delta = Math.abs(endTs - startTs); // difference in milliseconds

  const hours = Math.floor(delta / 3600_000); // 3600_000 ms in an hour
  delta %= 3600_000;

  const minutes = Math.floor(delta / 60_000); // 60_000 ms in a minute
  delta %= 60_000;

  const seconds = Math.floor(delta / 1_000);
  delta %= 1_000;

  const milliseconds = Math.floor(delta);

  const parts = [];
  if (hours) parts.push(hours + "h");
  if (minutes) parts.push(minutes + "min");
  if (seconds && seconds > 0) parts.push(seconds + "s");
  if (milliseconds) parts.push(milliseconds + "ms");

  return parts.join(" ");
}


/**
 *
 * @param {!File} file
 */
async function decompressFile(file) {
  const stream = file.stream();

  const decompressedStream = stream.pipeThrough(
    new DecompressionStream("gzip")
  );

  const response = new Response(decompressedStream);
  return await response.text();
}
