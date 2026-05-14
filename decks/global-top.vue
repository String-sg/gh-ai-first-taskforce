<template>
  <div class="dxd-chrome" aria-hidden="true">

    <!-- Full-bleed background shapes -->
    <svg class="bg-svg" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1280 720" preserveAspectRatio="none">

      <!-- Thin lime accent bar along the top edge -->
      <rect x="0" y="0" width="1280" height="4" fill="#AEDC41" opacity="0.9" />

      <!-- Large lime circle wash, bottom-right corner -->
      <circle cx="1220" cy="680" r="260" fill="#AEDC41" fill-opacity="0.07" />

      <!-- Navy circle wash, top-left corner -->
      <circle cx="-20" cy="-20" r="180" fill="#1B2D60" fill-opacity="0.06" />

      <!-- DxD sparkle, bottom-left — lime -->
      <g transform="translate(40,595) scale(0.6)" opacity="0.12">
        <path d="M50,0 C47,30 70,47 100,50 C70,53 47,70 50,100 C53,70 30,53 0,50 C30,47 53,30 50,0 Z" fill="#AEDC41" />
      </g>

      <!-- DxD sparkle, top-right (behind logo) — navy -->
      <g transform="translate(1160,6) scale(0.38)" opacity="0.10">
        <path d="M50,0 C47,30 70,47 100,50 C70,53 47,70 50,100 C53,70 30,53 0,50 C30,47 53,30 50,0 Z" fill="#1B2D60" />
      </g>

    </svg>

    <!-- Logo pinned top-right -->
    <img class="dxd-logo" src="/dxd-logo.jpeg" alt="DxD" />

  </div>
</template>

<style scoped>
.dxd-chrome {
  position: fixed;
  inset: 0;
  pointer-events: none;
  z-index: 50;
}

.bg-svg {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
}

.dxd-logo {
  position: absolute;
  top: 14px;
  right: 18px;
  height: 26px;
  width: auto;
  object-fit: contain;
}
</style>
