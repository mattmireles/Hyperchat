# Field Guide: Automating ProseMirror + React/Next + WebKit with Playwright

*Purpose —* Token-tight reference for LLM-driven code generation & debugging. Combines quick-reference tables with complete implementation patterns.

---

## 0. Core Ideas (memorize these)

1. **Programmatic > UI** for ProseMirror: build & dispatch transactions directly; DOM is a side-effect
2. **Wait for state, not time**: Playwright auto-waits + web-first assertions replace `waitForTimeout()`
3. **Hydration is your race-condition**: disable-until-ready or expose a `data-hydrated` flag
4. **Three-step navigation** for `next/link`: *click → waitForURL → expect(dest locator)*
5. **WebKit is different**: test every PR in Safari; keep quirks list handy

---

## 1. ProseMirror: Programmatic Automation

### 1.1 Holy Trinity

| API | Role | Cheat-sheet |
|-----|------|-------------|
| `EditorState` | Immutable snapshot (`state.doc`, `state.selection`, plugin config) | Read/assert here, *never* DOM |
| `EditorView` | Renders state → DOM; captures UI → transactions | Expose as `window.pmView` in test mode |
| `Transaction` | Description of change; built via `state.tr` | Dispatch with `view.dispatch(tr)` |

### 1.2 Setup & Helpers

```typescript
// React component - expose view (@nytimes/react-prosemirror or similar)
useEditorEffect(view => {
  if (process.env.NODE_ENV === 'test' && view) {
    window.pmView = view;
  }
}, []);

// Test helper - complete implementation
export async function pmDispatch(page: Page, builder: (state: any, tr: any) => any) {
  await page.evaluate((builderString) => {
    const view = (window as any).pmView;
    if (!view) throw new Error("ProseMirror view not found");
    const { state, dispatch } = view;
    const builderFunc = new Function('state', 'tr', `return (${builderString})(state, tr);`);
    const tr = builderFunc(state, state.tr);
    if (tr) dispatch(tr);
  }, builder.toString());
}
```

### 1.3 Common Operations

```typescript
// Insert text
await pmDispatch(page, (state, tr) => tr.insertText('hello', pos));

// Set selection
await pmDispatch(page, (state, tr) => {
  const { TextSelection } = state.selection.constructor;
  return tr.setSelection(TextSelection.create(state.doc, from, to));
});

// Apply mark
await pmDispatch(page, (state, tr) => {
  const mark = state.schema.marks.strong.create();
  return tr.addMark(from, to, mark);
});

// Direct command execution
await page.evaluate(() => {
  const { splitBlock } = window.pmCommands; // expose commands too
  splitBlock(window.pmView.state, window.pmView.dispatch);
});
```

### 1.4 Edge Cases

| Gotcha | Symptom | Fix | Details |
|--------|---------|-----|---------|
| DOM assertions | Flaky innerHTML | Inspect `state.doc.toJSON()` | DOM is side-effect |
| Command chains | `Enter` unpredictable | Call specific command | `chainCommands(newlineInCode, createParagraphNear, liftEmptyBlock, splitBlock)` |
| Position math | Off-by-1 errors | Remember token count | `<p></p>` = size 2, cursor at 1 |
| Auto-join plugin | Delete merges lists | Disable or assert merged | Plugin wraps delete command |

---

## 2. React & Next.js: Async + Hydration

### 2.1 React Reconciliation

```javascript
// ❌ WRONG - immediate check
await page.click('#submit');
expect(await page.locator('.success').isVisible()).toBe(true);

// ✅ RIGHT - auto-retrying assertion  
await page.click('#submit');
await expect(page.locator('.success')).toBeVisible();
```

### 2.2 Hydration Patterns

| Pattern | Safe Signal | Implementation |
|---------|-------------|----------------|
| **Disabled-until-ready** (best) | `disabled` removed | See code below |
| **data-hydrated** attr | `body[data-hydrated="true"]` | Root layout hook |
| **toPass** polling | No simple signal | Retry entire block |

```javascript
// Pattern 1: Component fix
export const HydrationAwareButton = ({ onClick, children }) => {
  const [isMounted, setIsMounted] = useState(false);
  useEffect(() => { setIsMounted(true); }, []);
  return <button onClick={onClick} disabled={!isMounted}>{children}</button>;
};

// Pattern 2: Test-side signal
// In _app.js or layout.js
useEffect(() => {
  document.body.setAttribute('data-hydrated', 'true');
}, []);

// In test
await page.goto('/ssr-page');
await page.waitForSelector('body[data-hydrated="true"]');

// Pattern 3: Retry pattern
await expect(async () => {
  await page.getByRole("button").click();
  await expect(page.getByText("Success!")).toBeVisible();
}).toPass();
```

### 2.3 Navigation Patterns

```typescript
// next/link client-side (no waitForNavigation!)
await page.getByRole('link', { name: 'About' }).click();
await page.waitForURL('**/about');
await expect(page.getByRole('heading', { name: /about/i })).toBeVisible();
```

**Note**: `next/link` prefetches visible links - network idle is meaningless

### 2.4 Data Fetching Strategies

| Mode | When Fetched | Test Approach | Key Detail |
|------|--------------|---------------|------------|
| **SSR** | Each request | `page.route()` or seeded DB | Works on dev & prod |
| **SSG** | Build time | Dev mode + `page.route()` | Prod build = frozen data |
| **ISR** | Build + revalidate | Trigger → poll with `toPass()` | Unpredictable timing |
| **CSR** | Browser runtime | Assert final DOM | `waitForResponse()` optional |

```typescript
// SSG testing - MUST use dev mode
test('SSG with different data', async ({ page }) => {
  // Only works with `npm run dev`
  await page.route('**/api/data', route => 
    route.fulfill({ json: { title: 'Mocked' } })
  );
  await page.goto('/static-page');
});
```

---

## 3. Playwright Patterns

### 3.1 Locator Hierarchy

1. `getByRole()` / `getByLabel()` / `getByText()`
2. `getByTestId()` - configure `testIdAttribute` in config
3. CSS/XPath → *only if forced*

### 3.2 Authentication Setup

```typescript
// auth.setup.ts - runs once
await page.goto('/login');
await page.fill('#email', 'test@example.com');
await page.fill('#password', 'password');
await page.click('#submit');
await page.context().storageState({ path: 'auth.json' });

// playwright.config.ts
projects: [
  { name: 'setup', testMatch: /auth\.setup\.ts/ },
  { 
    name: 'e2e',
    dependencies: ['setup'],
    use: { storageState: 'auth.json' }
  }
]
```

### 3.3 Component Testing (Fast Loop)

```typescript
import { test, expect } from '@playwright/experimental-ct-react';
import { ProseMirrorEditor } from './Editor';

test('editor interaction', async ({ mount }) => {
  const component = await mount(
    <ProseMirrorEditor initialContent="<p>Hello</p>" />
  );
  const editor = component.locator('.ProseMirror');
  
  await expect(editor).toContainText('Hello');
  await editor.press('End');
  await editor.type(' World');
  await expect(editor).toContainText('Hello World');
});
```

---

## 4. WebKit Quirks Cheat-Sheet

| Area | Quirk | Quick Fix | Implementation |
|------|-------|-----------|----------------|
| **contentEditable** | `-webkit-user-select: none` breaks focus | Remove style | See code below |
| **Focus/blur** | Blur events missing | Force blur | `body.click({position:{x:0,y:0}})` |
| **CSS Layout** | See details → | Visual tests | Multiple specific bugs |
| **User Activation** | APIs need trusted event | Real click first | `clipboard.writeText`, `window.open` |

### 4.1 ContentEditable Fix

```javascript
// WebKit-specific workaround
await page.evaluate(() => {
  const editor = document.querySelector('.ProseMirror');
  let parent = editor.parentElement;
  while (parent) {
    if (getComputedStyle(parent).webkitUserSelect === 'none') {
      parent.style.webkitUserSelect = '';
    }
    parent = parent.parentElement;
  }
});
```

### 4.2 CSS Rendering Specifics

- **Flexbox**: `flex-grow` different in nested contexts
- **position: sticky**: Broken on `<thead>` elements  
- **border-radius**: Ignored on `outline` property
- **mask-image**: Sub-pixel gaps at certain widths

---

## 5. Complete Test Example

```typescript
test('ProseMirror complex operation', async ({ page }) => {
  await page.goto('/editor');
  
  // Wait for hydration
  await page.waitForSelector('body[data-hydrated="true"]');
  
  // Insert formatted text
  await pmDispatch(page, (state, tr) => {
    return tr.insertText('Hello World');
  });
  
  // Select "Hello" (positions 1-6)
  await pmDispatch(page, (state, tr) => {
    const { TextSelection } = state.selection.constructor;
    return tr.setSelection(TextSelection.create(state.doc, 1, 6));
  });
  
  // Apply bold
  await pmDispatch(page, (state, tr) => {
    const mark = state.schema.marks.strong.create();
    return tr.addMark(state.selection.from, state.selection.to, mark);
  });
  
  // Verify state, not DOM
  const content = await page.evaluate(() => {
    return window.pmView.state.doc.toJSON();
  });
  
  expect(content.content[0].content[0].marks[0].type).toBe('strong');
});
```

---

## 6. Quick Debugging Checklist

### ProseMirror
- [ ] `window.pmView` exposed?
- [ ] Using transactions not UI events?
- [ ] Position math correct? (empty para = size 2)

### React/Next  
- [ ] Web-first assertions (`expect(locator).toBeVisible()`)?
- [ ] Hydration signal awaited?
- [ ] 3-step nav for next/link?

### WebKit
- [ ] Test `-webkit-user-select: none` on parents?
- [ ] Force blur after contentEditable?
- [ ] Visual regression for CSS bugs?
- [ ] User activation before restricted APIs?

### Data & State
- [ ] Test isolated?
- [ ] SSG variants in dev mode only?
- [ ] Auth via storage state?

---

## Glossary

- **Grey-box**: Tests know internals (transactions, hydration flags) but exercise full stack
- **Actionability**: Playwright's pre-action wait (attached + visible + stable + enabled)
- **toPass()**: Retries async block until success or timeout
- **Hydration**: Client React taking over server-rendered HTML
- **Token**: ProseMirror position unit (char = 1, node boundary = 1)
