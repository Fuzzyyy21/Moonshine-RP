const $ = (id) => document.getElementById(id);
let total = 0;

function format(seconds) {
    const minutes = Math.floor(seconds / 60);
    return `${minutes}:${String(seconds % 60).padStart(2, '0')}`;
}

window.addEventListener('message', (event) => {
    const { action, data } = event.data || {};

    if (action === 'death') {
        $('death').classList.toggle('hidden', !data.visible);
        if (data.visible) total = 0;

    } else if (action === 'deathUpdate') {
        if (total === 0) total = Math.max(1, data.remaining);

        $('timer').textContent = format(data.remaining);
        $('bar-fill').style.width = Math.max(0, Math.min(100, (data.remaining / total) * 100)) + '%';
        $('call-key').textContent = data.callKey || 'E';
        $('respawn-key').textContent = data.respawnKey || 'G';

        const locked = data.untilRespawn > 0;
        $('respawn-hint').classList.toggle('locked', locked);
        $('respawn-text').textContent = locked
            ? `Aufgeben in ${format(data.untilRespawn)}`
            : 'Aufgeben';
    }
});
