/**
 * OffData Landing Page - JavaScript
 * Manejo de interacciones, animaciones y navegación de la landing page
 */

(function () {
  'use strict';

  document.addEventListener('DOMContentLoaded', () => {
    // Smooth scrolling para enlaces internos
    const internalLinks = document.querySelectorAll('a[href^="#"]');
    internalLinks.forEach(link => {
      link.addEventListener('click', (e) => {
        const targetId = link.getAttribute('href');
        if (targetId && targetId !== '#') {
          const targetEl = document.querySelector(targetId);
          if (targetEl) {
            e.preventDefault();
            targetEl.scrollIntoView({ behavior: 'smooth' });
          }
        }
      });
    });

    // Tracking de descargas del APK
    const downloadBtns = document.querySelectorAll('a[download]');
    downloadBtns.forEach(btn => {
      btn.addEventListener('click', () => {
        console.log('Descarga de OffData APK iniciada por el usuario.');
      });
    });
  });
})();
