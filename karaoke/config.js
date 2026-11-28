// Fill this in after creating your Firebase project and YouTube API key (see README.md).
// With firebase left null, the sites run in DEMO MODE: the queue lives in this browser only,
// so the signup page and the console work together in two tabs of the same browser.
window.KARAOKE_CONFIG = {
  firebase: {
    apiKey: "AIzaSyA6FUrX4SY5Jpd1STPPhwQgXk77I_0gnzQ",
    authDomain: "beatswall-74884.firebaseapp.com",
    databaseURL: "https://beatswall-74884-default-rtdb.firebaseio.com",
    projectId: "beatswall-74884",
    storageBucket: "beatswall-74884.firebasestorage.app",
    messagingSenderId: "612651502606",
    appId: "1:612651502606:web:cc6b607fedb1680fa9c05f",
  },
  // Example:
  // firebase: {
  //   apiKey: "...", authDomain: "your-project.firebaseapp.com",
  //   databaseURL: "https://your-project-default-rtdb.firebaseio.com",
  //   projectId: "your-project", appId: "..."
  // },
  youtubeKey: '', // YouTube Data API v3 key. Empty = no search box, paste-a-link only.
};
