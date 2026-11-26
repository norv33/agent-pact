// AgentPact frontend — ethers.js v6, injected provider only.
// Never asks for a seed phrase, private key, API secret, or pairing code.
// All transactions are confirmed by the user in their own wallet.

const PACT_ABI = [
  "function createPact(string title, uint256 deadline) returns (uint256)",
  "function joinPact(uint256 pactId)",
  "function resolvePact(uint256 pactId, bool success)",
  "function totalPacts() view returns (uint256)",
  "function getPact(uint256 pactId) view returns (uint256 id, address creator, string title, uint256 deadline, uint256 createdAt, uint256 participantCount, uint256 successCount, uint256 failCount)",
  "function getParticipants(uint256 pactId) view returns (address[])",
  "function isParticipant(uint256 pactId, address account) view returns (bool)",
  "function getResolution(uint256 pactId, address account) view returns (bool resolved, bool success)",
  "function AGENT_ID() view returns (address)",
  "event PactCreated(uint256 indexed id, address indexed creator, string title, uint256 deadline)",
  "event PactJoined(uint256 indexed id, address indexed participant)",
  "event PactResolved(uint256 indexed id, address indexed participant, bool success)"
];

const AGENT_ID_ABI = [
  "function balanceOf(address account) view returns (uint256)"
];

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

let readProvider = null;
let readContract = null;
let signer = null;
let signerContract = null;
let userAddress = null;
let hasAgentId = false;
let pacts = [];
let filter = "all";

const $ = (id) => document.getElementById(id);

function shortAddr(addr) {
  return addr.slice(0, 6) + "…" + addr.slice(-4);
}

function fmtDeadline(ts) {
  return new Date(Number(ts) * 1000).toLocaleString();
}

function isDeployed() {
  return CONFIG.CONTRACT_ADDRESS.toLowerCase() !== ZERO_ADDRESS;
}

async function init() {
  readProvider = new ethers.JsonRpcProvider(CONFIG.RPC_URL);
  if (isDeployed()) {
    readContract = new ethers.Contract(CONFIG.CONTRACT_ADDRESS, PACT_ABI, readProvider);
    $("contractLine").innerHTML =
      `Contract: <a href="${CONFIG.EXPLORER_BASE}/address/${CONFIG.CONTRACT_ADDRESS}" target="_blank" rel="noopener">${CONFIG.CONTRACT_ADDRESS}</a> (${CONFIG.CHAIN_NAME})`;
  } else {
    $("deployNotice").classList.remove("hidden");
  }

  $("connectBtn").addEventListener("click", connect);
  $("createBtn").addEventListener("click", createPact);
  $("refreshBtn").addEventListener("click", loadPacts);
  document.querySelectorAll(".filter-btn").forEach((b) => {
    b.addEventListener("click", () => {
      document.querySelectorAll(".filter-btn").forEach((x) => x.classList.remove("active"));
      b.classList.add("active");
      filter = b.dataset.filter;
      render();
    });
  });

  // Default deadline: 7 days from now, for convenience.
  const d = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
  $("pactDeadline").value = d.toISOString().slice(0, 16);

  await loadPacts();
}

async function connect() {
  if (!window.ethereum) {
    alert("No wallet found. Install MetaMask or use Binance Wallet, then try again.");
    return;
  }
  try {
    const provider = new ethers.BrowserProvider(window.ethereum);
    const network = await provider.getNetwork();
    if (Number(network.chainId) !== CONFIG.CHAIN_ID) {
      $("networkNotice").textContent =
        `Please switch your wallet to ${CONFIG.CHAIN_NAME} (chain ${CONFIG.CHAIN_ID}). ` +
        `You are currently on chain ${network.chainId}.`;
      $("networkNotice").classList.remove("hidden");
      try {
        await window.ethereum.request({
          method: "wallet_switchEthereumChain",
          params: [{ chainId: "0x" + CONFIG.CHAIN_ID.toString(16) }]
        });
        $("networkNotice").classList.add("hidden");
      } catch (e) {
        return; // user declined the switch; stop here
      }
    }
    signer = await provider.getSigner();
    userAddress = await signer.getAddress();
    $("walletStatus").textContent = "Connected: " + shortAddr(userAddress);
    $("connectBtn").textContent = "Connected";

    // Agent ID check (read-only call, no transaction).
    const agentId = new ethers.Contract(CONFIG.AGENT_ID_ADDRESS, AGENT_ID_ABI, provider);
    const balance = await agentId.balanceOf(userAddress);
    hasAgentId = balance > 0n;
    $("agentIdStatus").textContent = "Agent ID: " + (hasAgentId ? "Yes ✓" : "No — you need an Agent ID to create or join pacts");
    $("agentIdStatus").classList.toggle("good", hasAgentId);
    $("agentIdStatus").classList.toggle("bad", !hasAgentId);

    if (isDeployed()) {
      signerContract = new ethers.Contract(CONFIG.CONTRACT_ADDRESS, PACT_ABI, signer);
      $("createBtn").disabled = !hasAgentId;
    }
    await loadPacts();
  } catch (err) {
    console.error(err);
    alert("Could not connect wallet: " + (err.message || err));
  }
}

async function loadPacts() {
  const list = $("pactList");
  if (!isDeployed()) {
    list.innerHTML = '<p class="hint">No pacts yet — the contract is not deployed on this network.</p>';
    return;
  }
  list.innerHTML = '<p class="hint">Loading pacts…</p>';
  try {
    const total = await readContract.totalPacts();
    const rows = [];
    for (let i = 0; i < Number(total); i++) {
      const p = await readContract.getPact(i);
      const row = {
        id: Number(p.id),
        creator: p.creator,
        title: p.title,
        deadline: Number(p.deadline),
        createdAt: Number(p.createdAt),
        participantCount: Number(p.participantCount),
        successCount: Number(p.successCount),
        failCount: Number(p.failCount),
        isMine: false,
        isParticipant: false,
        resolved: false,
        success: false
      };
      if (userAddress) {
        row.isMine = row.creator.toLowerCase() === userAddress.toLowerCase();
        row.isParticipant = await readContract.isParticipant(i, userAddress);
        if (row.isParticipant) {
          const r = await readContract.getResolution(i, userAddress);
          row.resolved = r[0];
          row.success = r[1];
        }
      }
      rows.push(row);
    }
    // Newest first.
    pacts = rows.reverse();
    render();
  } catch (err) {
    console.error(err);
    list.innerHTML = '<p class="hint">Could not load pacts. Check your connection and try Refresh.</p>';
  }
}

function render() {
  const list = $("pactList");
  const now = Math.floor(Date.now() / 1000);
  let shown = pacts;
  if (filter === "mine") shown = pacts.filter((p) => p.isMine || p.isParticipant);
  if (filter === "open") shown = pacts.filter((p) => p.deadline > now);
  if (filter === "past") shown = pacts.filter((p) => p.deadline <= now);

  if (shown.length === 0) {
    list.innerHTML = '<p class="hint">No pacts match this filter yet.</p>';
    return;
  }

  list.innerHTML = "";
  for (const p of shown) {
    const past = p.deadline <= now;
    const div = document.createElement("div");
    div.className = "pact" + (past ? " past" : "");
    div.innerHTML = `
      <div class="pact-head">
        <strong>#${p.id} — ${escapeHtml(p.title)}</strong>
        <span class="badge">${past ? "Past deadline" : "Open"}</span>
      </div>
      <div class="pact-meta">
        by ${shortAddr(p.creator)} · deadline ${fmtDeadline(p.deadline)}<br>
        👥 ${p.participantCount} participant${p.participantCount === 1 ? "" : "s"} ·
        ✅ ${p.successCount} kept · ❌ ${p.failCount} broken
      </div>
      <div class="pact-actions"></div>
    `;
    const actions = div.querySelector(".pact-actions");

    if (userAddress && isDeployed()) {
      if (!past && !p.isParticipant) {
        const joinBtn = document.createElement("button");
        joinBtn.className = "btn";
        joinBtn.textContent = "Join";
        joinBtn.disabled = !hasAgentId;
        joinBtn.title = hasAgentId ? "" : "You need an Agent ID to join";
        joinBtn.addEventListener("click", () => joinPact(p.id));
        actions.appendChild(joinBtn);
      }
      if (past && p.isParticipant && !p.resolved) {
        const keptBtn = document.createElement("button");
        keptBtn.className = "btn good-btn";
        keptBtn.textContent = "I kept it ✓";
        keptBtn.addEventListener("click", () => resolvePact(p.id, true));
        const brokenBtn = document.createElement("button");
        brokenBtn.className = "btn bad-btn";
        brokenBtn.textContent = "I broke it ✗";
        brokenBtn.addEventListener("click", () => resolvePact(p.id, false));
        actions.appendChild(keptBtn);
        actions.appendChild(brokenBtn);
      }
      if (p.isParticipant && p.resolved) {
        const span = document.createElement("span");
        span.className = "status";
        span.textContent = p.success ? "You reported: kept ✓" : "You reported: broken ✗";
        actions.appendChild(span);
      }
      if (p.isParticipant && !p.resolved && !past) {
        const span = document.createElement("span");
        span.className = "status";
        span.textContent = "You joined — report after the deadline.";
        actions.appendChild(span);
      }
    } else if (!userAddress) {
      const span = document.createElement("span");
      span.className = "status";
      span.textContent = "Connect your wallet to join or resolve.";
      actions.appendChild(span);
    }

    list.appendChild(div);
  }
}

function escapeHtml(s) {
  return s.replace(/[&<>"']/g, (c) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
  })[c]);
}

async function createPact() {
  const title = $("pactTitle").value.trim();
  const deadlineStr = $("pactDeadline").value;
  const msg = $("createMsg");
  msg.textContent = "";

  if (!signerContract) {
    msg.textContent = "Connect your wallet first.";
    return;
  }
  if (title.length === 0 || title.length > CONFIG.MAX_TITLE_LENGTH) {
    msg.textContent = `Title must be 1–${CONFIG.MAX_TITLE_LENGTH} characters.`;
    return;
  }
  const deadline = Math.floor(new Date(deadlineStr).getTime() / 1000);
  const now = Math.floor(Date.now() / 1000);
  if (!deadline || deadline <= now) {
    msg.textContent = "Deadline must be in the future.";
    return;
  }
  if (deadline > now + CONFIG.MAX_DURATION_DAYS * 24 * 60 * 60) {
    msg.textContent = `Deadline must be within ${CONFIG.MAX_DURATION_DAYS} days.`;
    return;
  }

  try {
    msg.textContent = "Confirm the transaction in your wallet…";
    const tx = await signerContract.createPact(title, deadline);
    msg.textContent = "Waiting for confirmation…";
    await tx.wait();
    msg.textContent = "Pact created! 🎉";
    $("pactTitle").value = "";
    await loadPacts();
  } catch (err) {
    console.error(err);
    msg.textContent = "Failed: " + (err.reason || err.message || err);
  }
}

async function joinPact(id) {
  try {
    const tx = await signerContract.joinPact(id);
    await tx.wait();
    await loadPacts();
  } catch (err) {
    console.error(err);
    alert("Join failed: " + (err.reason || err.message || err));
  }
}

async function resolvePact(id, success) {
  try {
    const tx = await signerContract.resolvePact(id, success);
    await tx.wait();
    await loadPacts();
  } catch (err) {
    console.error(err);
    alert("Resolve failed: " + (err.reason || err.message || err));
  }
}

window.addEventListener("DOMContentLoaded", init);
