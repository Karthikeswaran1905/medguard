// Single shared Admin SDK app instance — every function file imports
// `db`/`auth`/`messaging` from here instead of re-initializing.
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import { getMessaging } from "firebase-admin/messaging";

initializeApp();

export const db = getFirestore();
export const auth = getAuth();
export const messaging = getMessaging();
