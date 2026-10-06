// Екран повторення: той самий кроковий інтерфейс, що й у занятті, але план
// складається лише з карток, час яких уже настав (`buildReviewPlan`).
//
// Малювання, перевірка відповідей і оцінки SRS живуть у `session.js`, щоб
// заняття й повторення не розходились у поведінці.

import { buildReviewPlan } from '../store.js';
import { createSessionView, reviewOptions } from './session.js';

export function renderReview(app) {
  const plan = buildReviewPlan(app.store, app.content);
  return createSessionView(app, plan, reviewOptions(app));
}
