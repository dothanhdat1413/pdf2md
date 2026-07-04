# Functionality

## Google Search Console verification

- The public site at `https://pdftomarkdown.co/` must expose a Google Search Console verification meta tag.
- The verification tag must use `name="google-site-verification"` and `content="L9PSq0KJ9d_PIqiDGp2xIC-K3gJ7Iy9EVYU2CLhZtWc"`.
- The tag should be emitted from app-wide metadata so the homepage includes it without adding client-side rendering logic.

### Testing notes

- Build the app and inspect the rendered homepage metadata for `<meta name="google-site-verification" content="L9PSq0KJ9d_PIqiDGp2xIC-K3gJ7Iy9EVYU2CLhZtWc">`.
- After deployment, fetch `https://pdftomarkdown.co/` and assert the verification meta tag is present in the HTML response.
