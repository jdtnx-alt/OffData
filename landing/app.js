// Copy to clipboard helper
function copyCode(text) {
  navigator.clipboard.writeText(text).then(() => {
    // Find clicked button
    const buttons = document.querySelectorAll('.btn-copy');
    buttons.forEach((btn) => {
      if (btn.getAttribute('onclick')?.includes(text)) {
        const originalText = btn.textContent;
        btn.textContent = '¡Copiado!';
        btn.style.background = '#22c55e';
        setTimeout(() => {
          btn.textContent = originalText;
          btn.style.background = '';
        }, 2000);
      }
    });
  }).catch((err) => {
    console.error('Error al copiar:', err);
  });
}

// Download feedback
document.addEventListener('DOMContentLoaded', () => {
  const downloadBtns = document.querySelectorAll('a[download]');
  downloadBtns.forEach((btn) => {
    btn.addEventListener('click', () => {
      const originalText = btn.innerHTML;
      btn.style.opacity = '0.85';
      setTimeout(() => {
        btn.style.opacity = '1';
      }, 1500);
    });
  });
});
