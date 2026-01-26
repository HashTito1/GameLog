# GameLog Landing Page Deployment Guide

This guide will help you deploy the GameLog landing page to get a legitimate URL for RAWG API registration.

## Option 1: GitHub Pages (Free & Easy)

1. **Create a GitHub Repository**
   ```bash
   # Create a new repository on GitHub named "gamelog-landing"
   git init
   git add .
   git commit -m "Initial commit: GameLog landing page"
   git branch -M main
   git remote add origin https://github.com/YOUR_USERNAME/gamelog-landing.git
   git push -u origin main
   ```

2. **Enable GitHub Pages**
   - Go to your repository settings
   - Scroll to "Pages" section
   - Select "Deploy from a branch"
   - Choose "main" branch and "/ (root)" folder
   - Click "Save"

3. **Your URL will be:**
   ```
   https://YOUR_USERNAME.github.io/gamelog-landing/
   ```

## Option 2: Netlify (Free with Custom Domain)

1. **Deploy to Netlify**
   - Go to [netlify.com](https://netlify.com)
   - Sign up/login
   - Drag and drop the `web_landing` folder
   - Or connect your GitHub repository

2. **Your URL will be:**
   ```
   https://random-name-12345.netlify.app
   ```

3. **Optional: Custom Domain**
   - Buy a domain (e.g., gamelog-app.com)
   - Add custom domain in Netlify settings

## Option 3: Vercel (Free)

1. **Deploy to Vercel**
   - Go to [vercel.com](https://vercel.com)
   - Import your GitHub repository
   - Deploy automatically

2. **Your URL will be:**
   ```
   https://gamelog-landing.vercel.app
   ```

## Option 4: Firebase Hosting (Free)

1. **Install Firebase CLI**
   ```bash
   npm install -g firebase-tools
   ```

2. **Initialize Firebase**
   ```bash
   firebase login
   firebase init hosting
   ```

3. **Deploy**
   ```bash
   firebase deploy
   ```

4. **Your URL will be:**
   ```
   https://your-project-id.web.app
   ```

## Recommended for RAWG API Registration

For RAWG API registration, I recommend using **GitHub Pages** because:
- It's free and reliable
- GitHub is a trusted platform
- The URL looks professional
- Easy to set up and maintain

## Files to Upload

Make sure to upload these files:
- `index.html` (main landing page)
- `privacy.html` (privacy policy)
- `README.md` (project documentation)

## After Deployment

Once deployed, you can use your URL when registering for the RAWG API:

1. Go to [rawg.io/apidocs](https://rawg.io/apidocs)
2. Sign up for an account
3. Fill in the developer form with:
   - **App Name**: GameLog
   - **App Description**: Personal game library and discovery platform
   - **Website URL**: Your deployed URL
   - **App Type**: Mobile/Web Application

Your legitimate app URL will help you get approved for the RAWG API key!