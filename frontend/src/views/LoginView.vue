<template>
  <div class="login">
    <div class="login-card">
      <div class="logo-wrap">
        <svg width="240" height="52" viewBox="0 0 320 60" fill="none" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <linearGradient id="lg-login" x1="0" y1="0" x2="60" y2="60" gradientUnits="userSpaceOnUse">
              <stop offset="0%" stop-color="#60a5fa"/>
              <stop offset="100%" stop-color="#a78bfa"/>
            </linearGradient>
          </defs>
          <text x="0" y="46" font-family="'Arial Black','Helvetica Neue',Arial,sans-serif" font-size="46" font-weight="900" fill="url(#lg-login)">K</text>
          <text x="36" y="46" font-family="'Arial Black','Helvetica Neue',Arial,sans-serif" font-size="46" font-weight="900" fill="white">ontor</text>
        </svg>
      </div>
      <p class="subtitle">AI-driven email, unified.</p>

      <div class="actions">
        <a :href="googleAuthUrl" class="btn btn-google">
          Continue with Google
        </a>
        <a :href="microsoftAuthUrl" class="btn btn-microsoft">
          Continue with Microsoft
        </a>
      </div>
    </div>
  </div>
</template>

<script setup>
const googleAuthUrl = `/api/v1/auth/google/redirect`
const microsoftAuthUrl = `/api/v1/auth/microsoft/redirect`
</script>

<style scoped>
.login {
  height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #0f0f0f;
}

.login-card {
  background: #141414;
  border: 1px solid #2a2a2a;
  border-radius: 16px;
  padding: 48px 40px;
  width: 360px;
  text-align: center;
}

.logo-wrap {
  display: flex;
  justify-content: center;
  margin-bottom: 8px;
}

.subtitle {
  color: #666;
  font-size: 14px;
  margin-bottom: 36px;
}

.actions {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.btn {
  display: block;
  padding: 12px 24px;
  border-radius: 8px;
  font-size: 14px;
  font-weight: 500;
  text-decoration: none;
  transition: opacity 0.15s;
}

.btn:hover { opacity: 0.85; }

.btn-google {
  background: #fff;
  color: #1a1a1a;
}

.btn-microsoft {
  background: #0078d4;
  color: #fff;
}
</style>
