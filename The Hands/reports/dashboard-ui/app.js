const fmt = new Intl.NumberFormat();

function setText(id, value) {
  document.getElementById(id).textContent = value;
}

function drawBarChart(canvas, signals) {
  const ctx = canvas.getContext("2d");
  const entries = Object.entries(signals || {});
  const width = canvas.width;
  const height = canvas.height;
  ctx.clearRect(0, 0, width, height);
  ctx.fillStyle = "#ffffff";
  ctx.fillRect(0, 0, width, height);
  if (!entries.length) {
    ctx.fillStyle = "#5f6f80";
    ctx.fillText("No signal data yet", 20, 30);
    return;
  }
  const max = Math.max(...entries.map(([, value]) => value), 1);
  const barWidth = Math.max(28, (width - 60) / entries.length - 12);
  entries.forEach(([label, value], index) => {
    const x = 34 + index * (barWidth + 12);
    const barHeight = Math.round((height - 70) * (value / max));
    const y = height - 38 - barHeight;
    ctx.fillStyle = "#2a6f97";
    ctx.fillRect(x, y, barWidth, barHeight);
    ctx.fillStyle = "#14213d";
    ctx.font = "13px system-ui";
    ctx.fillText(String(value), x, y - 8);
    ctx.save();
    ctx.translate(x, height - 18);
    ctx.rotate(-0.35);
    ctx.fillText(label, 0, 0);
    ctx.restore();
  });
}

async function loadAssessment() {
  const response = await fetch("The Hands/reports/data/log-assessments/latest/assessment.json", { cache: "no-store" });
  if (!response.ok) throw new Error(`assessment fetch failed: ${response.status}`);
  return response.json();
}

function render(data) {
  const risk = (data.risk || "unknown").toLowerCase();
  document.getElementById("risk").innerHTML = `<span class="risk ${risk}">${risk.toUpperCase()}</span>`;
  setText("generated", `Generated ${data.generated_at || "unknown"} for ${data.date || "today"}`);
  const signalTotal = Object.values(data.signals || {}).reduce((sum, value) => sum + Number(value || 0), 0);
  setText("signalCount", fmt.format(signalTotal));
  setText("serviceCount", fmt.format(Object.keys(data.services || {}).length));
  setText("notableCount", fmt.format((data.notable_events || []).length));
  setText("assessment", data.assessment || "No assessment generated yet.");
  document.getElementById("recommendations").innerHTML = (data.recommendations || [])
    .map(item => `<li>${item}</li>`).join("");
  document.getElementById("services").innerHTML = Object.entries(data.services || {})
    .map(([service, stats]) => `<tr><td>${service}</td><td>${fmt.format(stats.lines_sampled || 0)}</td><td>${fmt.format(stats.files_sampled || 0)}</td><td><code>${JSON.stringify(stats.signals || {})}</code></td></tr>`)
    .join("");
  document.getElementById("events").innerHTML = (data.notable_events || [])
    .map(event => `<tr><td>${event.service}</td><td><code>${event.file}</code></td><td>${event.message}</td></tr>`)
    .join("");
  drawBarChart(document.getElementById("signalChart"), data.signals || {});
}

loadAssessment()
  .then(render)
  .catch(error => {
    setText("generated", "No assessment report found yet. Start the dashboard/log assessment profile.");
    setText("assessment", error.message);
  });

