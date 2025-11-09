## BookSwap App

A Flutter + Firebase mobile application that allows students to **list textbooks**, **browse available books**, and **initiate swaps** with other users in real time.



## Features

- **User Authentication** – Email/password login, signup, and email verification using Firebase Auth.  
- **Book Listings (CRUD)** – Users can post, edit, delete, and browse books in real-time via Firestore.  
- **Swap Functionality** – Users can request swaps; states update instantly (`pending`, `accepted`, `rejected`).  
- **Navigation** – BottomNavigationBar for Browse, My Listings, Chats, and Settings screens.  
- **Chat (Bonus)** – Real-time chat between users after swap initiation.  
- **Settings** – Profile info and notification toggle simulation.  
- **Real-Time Sync** – Firestore snapshot listeners keep data updated instantly.  
- **State Management** – Implemented using `Provider` with `ChangeNotifier`.



## Build & Run Steps

Follow these steps to run the app locally:

1. **Clone the Repository**
   ```bash
   git clone https://github.com/milkakeza/BookSwapApp.git
   cd bookswap-app

2. **Install Dependencies**
   ```flutter pub get

3. **Set Up Firebase**
   ```Go to the Firebase Console
   Create a new project called bookswap-app.

   Add Android, iOS, and Web apps.

   Download google-services.json (Android) and GoogleService-Info.plist (iOS), and place them in their respective folders:
    android/app/google-services.json
    ios/Runner/GoogleService-Info.plist

   Enable Authentication, Cloud Firestore, and Storage in Firebase.

4. **Run the app**
   ```flutter run

## Architecture Overview
### Architecture Structure

The app follows the below architecture pattern with clear separation of concerns:

lib/
├── models/          # Data models (Book, User, Swap)
├── services/        # Firebase logic (Auth, Firestore, Storage)
├── providers/       # State management using Provider
├── screens/         # UI screens (Browse, My Listings, Swap, Settings)
├── widgets/         # Reusable UI components
└── main.dart        # App entry point with Providers and routing

## Diagram

![Architecture Diagram](<Screenshot 2025-11-09 at 23.51.26.png>)

### State Management Explanation

The app uses the Provider package for reactive state management:

AuthProvider manages authentication states.

BookProvider manages CRUD operations and swap requests.

notifyListeners() triggers automatic UI updates.

Real-time streams from Firestore ensure data consistency without manual refresh.

### Swap State Design in Firestore
Collection: swaps
# Field: Description

`requestedBookId`: The book requested for swap
`offeredBookId`: The book offered in exchange
`requesterId`: UID of the user making the request
`receiverId`: UID of the book owner
`status`: `pending`, `accepted`, `rejected`, `cancelled`
`createdAt`: Timestamp for swap creation

## Database Schema Overview

Collections:

users/{uid} → user profiles

books/{bookId} → book listings with ownerId and status

swaps/{swapId} → swap requests with state tracking

chats/{chatId} → messages between users (optional)

## Author

Milka Isingizwe
m.isingizwe1@alustudent.com
African Leadership University – Software Engineering

