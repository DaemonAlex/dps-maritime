// Maritime Dashboard NUI Script

const dashboard = document.getElementById('dashboard');

// Unlock definitions
const UNLOCKS = [
    { name: 'Dock Work', level: 1, icon: '&#128230;' },
    { name: 'Boat Deliveries', level: 4, icon: '&#9973;' },
    { name: 'VIP Transport', level: 6, icon: '&#128100;' },
    { name: 'Fleet Ownership', level: 7, icon: '&#9875;' },
    { name: 'Hazmat Cargo', level: 6, icon: '&#9888;' },
    { name: 'Smuggler\'s Radar', level: 9, icon: '&#128225;' },
    { name: 'Master Captain', level: 10, icon: '&#127775;' },
];

// Format money with commas
function formatMoney(amount) {
    return '$' + amount.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

// Calculate XP progress
function calculateProgress(currentXP, currentLevel, levelData) {
    if (currentLevel >= 10) return 100;

    const currentLevelXP = levelData[currentLevel]?.xp || 0;
    const nextLevelXP = levelData[currentLevel + 1]?.xp || currentLevelXP + 1000;

    const xpIntoLevel = currentXP - currentLevelXP;
    const xpNeeded = nextLevelXP - currentLevelXP;

    return Math.floor((xpIntoLevel / xpNeeded) * 100);
}

// Update dashboard with player data
function updateDashboard(data) {
    // Level and title
    document.getElementById('player-level').textContent = data.level || 1;
    document.getElementById('player-title').textContent = data.title || 'Deckhand';

    // XP bar
    const progress = calculateProgress(data.xp || 0, data.level || 1, data.levelData || {});
    document.getElementById('xp-bar').style.width = progress + '%';

    const currentLevelXP = data.levelData?.[data.level]?.xp || 0;
    const nextLevelXP = data.levelData?.[data.level + 1]?.xp || currentLevelXP + 1000;
    document.getElementById('xp-text').textContent = `${data.xp || 0} / ${nextLevelXP} XP`;

    // Stats
    document.getElementById('boat-deliveries').textContent = data.boat_deliveries || 0;
    document.getElementById('dock-deliveries').textContent = data.dock_deliveries || 0;
    document.getElementById('total-earnings').textContent = formatMoney(data.total_earnings || 0);
    document.getElementById('current-streak').textContent = data.current_streak || 0;

    // Bonuses
    const payMultiplier = data.levelData?.[data.level]?.payMultiplier || 1;
    document.getElementById('pay-multiplier').textContent = Math.floor(payMultiplier * 100) + '%';

    const streakBonus = Math.min((data.current_streak || 0) * 2, 20); // 2% per streak, max 20%
    document.getElementById('streak-bonus').textContent = '+' + streakBonus + '%';

    // Unlocks
    const unlocksList = document.getElementById('unlocks-list');
    unlocksList.innerHTML = '';

    UNLOCKS.forEach(unlock => {
        const isUnlocked = (data.level || 1) >= unlock.level;
        const item = document.createElement('div');
        item.className = 'unlock-item ' + (isUnlocked ? 'unlocked' : 'locked');
        item.innerHTML = `
            <span class="unlock-icon">${unlock.icon}</span>
            <div class="unlock-info">
                <span class="unlock-name">${unlock.name}</span>
                <span class="unlock-level">Level ${unlock.level}${isUnlocked ? ' - Unlocked!' : ''}</span>
            </div>
        `;
        unlocksList.appendChild(item);
    });
}

// Show dashboard
function showDashboard(data) {
    updateDashboard(data);
    dashboard.classList.remove('hidden');
}

// Hide dashboard
function closeDashboard() {
    dashboard.classList.add('hidden');
    fetch(`https://${GetParentResourceName()}/closeDashboard`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
}

// Listen for NUI messages
window.addEventListener('message', function(event) {
    const data = event.data;

    switch (data.action) {
        case 'openDashboard':
            showDashboard(data.playerData);
            break;

        case 'closeDashboard':
            closeDashboard();
            break;

        case 'updateData':
            updateDashboard(data.playerData);
            break;
    }
});

// ESC key to close
document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape') {
        closeDashboard();
    }
});

// Fallback for GetParentResourceName if not in FiveM
if (typeof GetParentResourceName === 'undefined') {
    window.GetParentResourceName = function() {
        return 'dps-maritime';
    };
}
