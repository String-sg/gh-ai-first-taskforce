<template>
  <div class="dxd-footer">
    <span class="security-label">OFFICIAL (CLOSED)</span>
    <span class="page-number">{{ $slidev.nav.currentPage }} / {{ $slidev.nav.total }}</span>
  </div>
</template>

<style scoped>
.dxd-footer {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  pointer-events: none;
  z-index: 100;
}

.security-label {
  font-size: 10px;
  letter-spacing: 0.1em;
  color: #6b7280;
  text-transform: uppercase;
}

.page-number {
  position: absolute;
  right: 24px;
  font-size: 10px;
  color: #9ca3af;
}
</style>
