# dietary_app

This frontend is now maintained as a web-only Flutter application for the dietary assistant website.

## Scope

- Keep `lib/` and `web/` as the active frontend code.
- Remove native platform folders such as `android/`, `ios/`, `macos/`, `linux/`, and `windows/`.
- Use the FastAPI backend in `../../backend/` as the API service.

## Local Development

1. Start the backend on `http://localhost:8000`.
2. Use Flutter Web to run or build this frontend.
3. If the backend is deployed elsewhere, update the backend address in the settings page.

## Deployment

- Build the frontend as a static website.
- Deploy the generated web assets to any static hosting platform.
- Make sure the deployed frontend can reach the backend API through CORS or the same origin.
