:: borrowed from ~migrev-dolseg's %hawk
::
|%
++  feather
  ;style
    ; /* feather.css : terse utility classes */
    ; 
    ; 
    ; /*  part 1: resets  */
    ; 
    ; 
    ; *,
    ; *::before,
    ; *::after {
    ;   box-sizing: border-box;
    ;   margin: 0;
    ; }
    ; :not(:defined) {  /* hide undefined web components */
    ;   display: none;
    ; }
    ; html {
    ;   -moz-text-size-adjust: none;
    ;   -webkit-text-size-adjust: none;
    ;   text-size-adjust: none;
    ;   overflow: hidden;
    ;   font-size: 14px;
    ; }
    ; body, h1, h2, h3, h4, p,
    ; figure, blockquote, dl, dd {
    ;   margin-block-end: 0;
    ; }
    ; ul[role='list'],
    ; ol[role='list'] {
    ;   list-style: none;
    ; }
    ; h1, h2, h3, h4, h5, h6,
    ; button, input, label, select {
    ;   line-height: inherit;
    ; }
    ; button, summary {
    ;   cursor: pointer;
    ;   touch-action: manipulation;
    ; }
    ; h1, h2, h3,
    ; h4, h5, h6 {
    ;   text-wrap: balance;
    ;   font-size: 1em;
    ; }
    ; a {
    ;   text-decoration: none;
    ;   color: inherit;
    ; }
    ; iframe {
    ;   border: none;
    ;   background: white;
    ; }
    ; img,
    ; picture {
    ;   max-width: 100%;
    ;   display: block;
    ; }
    ; hr {
    ;   border: none;
    ;   height: 1px;
    ;   width: 100%;
    ;   background-color: var(--f8)
    ; }
    ; input, button,
    ; textarea, select {
    ;   padding: unset;
    ;   font-family: unset;
    ;   font-size: 1em;
    ;   background: unset;
    ;   border: unset;
    ;   border-radius: unset;
    ;   color: unset;
    ;   letter-spacing: unset;
    ;   line-height: inherit;
    ;   outline: none; }
    ; textarea  { resize: none; }
    ; b, strong { font-weight: bold; }
    ; i         { font-style: italic; }
    ; 
    ; 
    ; /*  part 2: variables  */
    ; 
    ;                   
    ; :root, :host {
    ;   --font-mono: Consolas, "SF Mono", Menlo, Monaco, "Liberation Mono", "DejaVu Mono", "Courier New", monospace;
    ;   --font-serif: "Georgia", "Times New Roman", "Liberation Serif", "DejaVu Serif", Times, serif;
    ;   --font-sans: Roboto, "Helvetica Neue", Helvetica, Arial, "Liberation Sans", "DejaVu Sans", sans-serif;
    ;   --mono-scale:   0.9;
    ;   --kerning:      0.024em;
    ;   --line-height:  1;
    ; 
    ;   --s0:   0px;
    ;   --s1:   2px;
    ;   --s2:   4px;
    ;   --s3:   8px;
    ;   --s4:  12px;
    ;   --s5:  16px;
    ;   --s6:  20px;
    ;   --s7:  25px;
    ;   --s8:  30px;
    ;   --s9:  36px;
    ;   --s10: 44px;
    ;   --s11: 52px;
    ;   --s12: 62px;
    ;   --s13: 74px;
    ;   --s14: 88px;
    ;   --s15: 104px;
    ;   --s16: 122px;
    ;   --s17: 143px;
    ;   --s18: 168px;
    ;   --s19: 196px;
    ;   --s20: 228px;
    ;   --s21: 265px;
    ;   --s22: 308px;
    ;   --s23: 358px;
    ;   --s24: 416px;
    ;   --s25: 484px;
    ;   --s26: 560px;
    ;   --s27: 648px;
    ;   --s28: 750px;
    ;   --s29: 870px;
    ;   --s30: 1000px;
    ; 
    ;   --p-page:       36px 12px clamp(100px, 36vh, 400px) 12px;
    ; 
    ;   --zinc-50: #fafafa;
    ;   --zinc-100: #f4f4f5;
    ;   --zinc-200: #e4e4e7;
    ;   --zinc-300: #d4d4d8;
    ;   --zinc-400: #A3A3A3;
    ;   --zinc-500: #838383;
    ;   --zinc-600: #727272;
    ;   --zinc-700: #3f3f46;
    ;   --zinc-800: #27272a;
    ;   --zinc-900: #18181b;
    ;   --zinc-950: #0f0f0f;
    ; 
    ;   --sky-50:  #f0f9ff;
    ;   --sky-100: #e0f2fe;
    ;   --sky-200: #bae6fd;
    ;   --sky-300: #7dd3fc;
    ;   --sky-400: #38bdf8;
    ;   --sky-500: #0ea5e9;
    ;   --sky-600: #0284c7;
    ;   --sky-700: #0369a1;
    ;   --sky-800: #075985;
    ;   --sky-900: #0c4a6e;
    ;   --sky-950: #082f49;
    ; 
    ;   --amber-50:  #fffbeb;
    ;   --amber-100: #fef3c7;
    ;   --amber-200: #fde68a;
    ;   --amber-300: #fcd34d;
    ;   --amber-400: #fbbf24;
    ;   --amber-500: #f59e0b;
    ;   --amber-600: #d97706;
    ;   --amber-700: #b45309;
    ;   --amber-800: #92400e;
    ;   --amber-900: #78350f;
    ;   --amber-950: #451a03;
    ; 
    ;   --lime-50:  #f7fee7;
    ;   --lime-100: #ecfccb;
    ;   --lime-200: #d9f99d;
    ;   --lime-300: #bef264;
    ;   --lime-400: #a3e635;
    ;   --lime-500: #84cc16;
    ;   --lime-600: #65a30d;
    ;   --lime-700: #4d7c0f;
    ;   --lime-800: #3f6212;
    ;   --lime-900: #365314;
    ;   --lime-950: #1a2e05;
    ; 
    ;   --red-50:  #fef2f2;
    ;   --red-100: #fee2e2;
    ;   --red-200: #fecaca;
    ;   --red-300: #fca5a5;
    ;   --red-400: #f87171;
    ;   --red-500: #ef4444;
    ;   --red-600: #dc2626;
    ;   --red-700: #b91c1c;
    ;   --red-800: #991b1b;
    ;   --red-900: #7f1d1d;
    ;   --red-950: #450a0a;
    ;   
    ;   --light-f-4:    #334dde;
    ;   --light-f-3:    #286e2c;
    ;   --light-f-2:    #e87800;
    ;   --light-f-1:    #d32f2f;
    ; 
    ;   --light-b-4:    #bbdefb;
    ;   --light-b-3:    #c8e6c9;
    ;   --light-b-2:    #fff9c4;
    ;   --light-b-1:    #ffccbc;
    ; 
    ;   --dark-f-4:     #8899ff;
    ;   --dark-f-3:     #66f699;
    ;   --dark-f-2:     #ffeb6b;
    ;   --dark-f-1:     #ff6d40;
    ; 
    ;   --dark-b-4:     #1a237e;
    ;   --dark-b-3:     #1b5e20;
    ;   --dark-b-2:     #472e12;
    ;   --dark-b-1:     #560c0c;
    ; }
    ; :root, :host {
    ;   --focus-color: #0000ff77;
    ;   --active-offset: 10%;
    ;   --percent-scale: 50%;
    ;   
    ;   --f-1: var(--light-f-1);
    ;   --f-2: var(--light-f-2);
    ;   --f-3: var(--light-f-3);
    ;   --f-4: var(--light-f-4);
    ;   
    ;   --b-1: var(--light-b-1);
    ;   --b-2: var(--light-b-2);
    ;   --b-3: var(--light-b-3);
    ;   --b-4: var(--light-b-4);
    ;   
    ;   --b0:           var(--zinc-50);
    ;   --b1:           var(--zinc-100);
    ;   --b2:           var(--zinc-200);
    ;   --b3:           var(--zinc-300);
    ;   --b4:           var(--zinc-400);
    ;   --b5:           var(--zinc-500);
    ;   --b6:           var(--zinc-600);
    ;   --b7:           var(--zinc-700);
    ;   --b8:           var(--zinc-800);
    ;   --b9:           var(--zinc-900);
    ;   --b10:          var(--zinc-950);
    ;   
    ;   --f0:           var(--zinc-950);
    ;   --f1:           var(--zinc-900);
    ;   --f2:           var(--zinc-800);
    ;   --f3:           var(--zinc-700);
    ;   --f4:           var(--zinc-600);
    ;   --f5:           var(--zinc-500);
    ;   --f6:           var(--zinc-400);
    ;   --f7:           var(--zinc-300);
    ;   --f8:           var(--zinc-200);
    ;   --f9:           var(--zinc-100);
    ;   --f10:          var(--zinc-50);
    ;   
    ;   .spring {
    ;     --b0:           var(--lime-50);
    ;     --b1:           var(--lime-100);
    ;     --b2:           var(--lime-200);
    ;     --b3:           var(--lime-300);
    ;     --b4:           var(--lime-400);
    ;     --b5:           var(--lime-500);
    ;     --b6:           var(--lime-600);
    ;     --b7:           var(--lime-700);
    ;     --b8:           var(--lime-800);
    ;     --b9:           var(--lime-900);
    ;     --b10:          var(--lime-950);
    ;     --f0:           var(--lime-950);
    ;     --f1:           var(--lime-900);
    ;     --f2:           var(--lime-800);
    ;     --f3:           var(--lime-700);
    ;     --f4:           var(--lime-600);
    ;     --f5:           var(--lime-500);
    ;     --f6:           var(--lime-400);
    ;     --f7:           var(--lime-300);
    ;     --f8:           var(--lime-200);
    ;     --f9:           var(--lime-100);
    ;     --f10:          var(--lime-50);
    ;   }
    ;   .summer {
    ;     --b0:           var(--red-50);
    ;     --b1:           var(--red-100);
    ;     --b2:           var(--red-200);
    ;     --b3:           var(--red-300);
    ;     --b4:           var(--red-400);
    ;     --b5:           var(--red-500);
    ;     --b6:           var(--red-600);
    ;     --b7:           var(--red-700);
    ;     --b8:           var(--red-800);
    ;     --b9:           var(--red-900);
    ;     --b10:          var(--red-950);
    ;     --f0:           var(--red-950);
    ;     --f1:           var(--red-900);
    ;     --f2:           var(--red-800);
    ;     --f3:           var(--red-700);
    ;     --f4:           var(--red-600);
    ;     --f5:           var(--red-500);
    ;     --f6:           var(--red-400);
    ;     --f7:           var(--red-300);
    ;     --f8:           var(--red-200);
    ;     --f9:           var(--red-100);
    ;     --f10:          var(--red-50);
    ;   }
    ;   .autumn {
    ;     --b0:           var(--amber-50);
    ;     --b1:           var(--amber-100);
    ;     --b2:           var(--amber-200);
    ;     --b3:           var(--amber-300);
    ;     --b4:           var(--amber-400);
    ;     --b5:           var(--amber-500);
    ;     --b6:           var(--amber-600);
    ;     --b7:           var(--amber-700);
    ;     --b8:           var(--amber-800);
    ;     --b9:           var(--amber-900);
    ;     --b10:          var(--amber-950);
    ;     --f0:           var(--amber-950);
    ;     --f1:           var(--amber-900);
    ;     --f2:           var(--amber-800);
    ;     --f3:           var(--amber-700);
    ;     --f4:           var(--amber-600);
    ;     --f5:           var(--amber-500);
    ;     --f6:           var(--amber-400);
    ;     --f7:           var(--amber-300);
    ;     --f8:           var(--amber-200);
    ;     --f9:           var(--amber-100);
    ;     --f10:          var(--amber-50);
    ;   }
    ;   .winter {
    ;     --b0:           var(--sky-50);
    ;     --b1:           var(--sky-100);
    ;     --b2:           var(--sky-200);
    ;     --b3:           var(--sky-300);
    ;     --b4:           var(--sky-400);
    ;     --b5:           var(--sky-500);
    ;     --b6:           var(--sky-600);
    ;     --b7:           var(--sky-700);
    ;     --b8:           var(--sky-800);
    ;     --b9:           var(--sky-900);
    ;     --b10:          var(--sky-950);
    ;     --f0:           var(--sky-950);
    ;     --f1:           var(--sky-900);
    ;     --f2:           var(--sky-800);
    ;     --f3:           var(--sky-700);
    ;     --f4:           var(--sky-600);
    ;     --f5:           var(--sky-500);
    ;     --f6:           var(--sky-400);
    ;     --f7:           var(--sky-300);
    ;     --f8:           var(--sky-200);
    ;     --f9:           var(--sky-100);
    ;     --f10:          var(--sky-50);
    ;   }
    ; }
    ; @media (prefers-color-scheme: dark) {
    ;   :root, :host {
    ;     --focus-color: #6666ff77;
    ;     --active-offset: 10%;
    ;     --percent-scale: 150%;
    ; 
    ;     --f-1: var(--dark-f-1);
    ;     --f-2: var(--dark-f-2);
    ;     --f-3: var(--dark-f-3);
    ;     --f-4: var(--dark-f-4);
    ;     
    ;     --b-1: var(--dark-b-1);
    ;     --b-2: var(--dark-b-2);
    ;     --b-3: var(--dark-b-3);
    ;     --b-4: var(--dark-b-4);
    ;     
    ;     --f0:           var(--zinc-50);
    ;     --f1:           var(--zinc-100);
    ;     --f2:           var(--zinc-200);
    ;     --f3:           var(--zinc-300);
    ;     --f4:           var(--zinc-400);
    ;     --f5:           var(--zinc-500);
    ;     --f6:           var(--zinc-600);
    ;     --f7:           var(--zinc-700);
    ;     --f8:           var(--zinc-800);
    ;     --f9:           var(--zinc-900);
    ;     --f10:          var(--zinc-950);
    ;     
    ;     --b0:           var(--zinc-950);
    ;     --b1:           var(--zinc-900);
    ;     --b2:           var(--zinc-800);
    ;     --b3:           var(--zinc-700);
    ;     --b4:           var(--zinc-600);
    ;     --b5:           var(--zinc-500);
    ;     --b6:           var(--zinc-400);
    ;     --b7:           var(--zinc-300);
    ;     --b8:           var(--zinc-200);
    ;     --b9:           var(--zinc-100);
    ;     --b10:          var(--zinc-50);
    ;     
    ;     .spring {
    ;       --f0:           var(--lime-50);
    ;       --f1:           var(--lime-100);
    ;       --f2:           var(--lime-200);
    ;       --f3:           var(--lime-300);
    ;       --f4:           var(--lime-400);
    ;       --f5:           var(--lime-500);
    ;       --f6:           var(--lime-600);
    ;       --f7:           var(--lime-700);
    ;       --f8:           var(--lime-800);
    ;       --f9:           var(--lime-900);
    ;       --f10:          var(--lime-950);
    ;       
    ;       --b0:           var(--lime-950);
    ;       --b1:           var(--lime-900);
    ;       --b2:           var(--lime-800);
    ;       --b3:           var(--lime-700);
    ;       --b4:           var(--lime-600);
    ;       --b5:           var(--lime-500);
    ;       --b6:           var(--lime-400);
    ;       --b7:           var(--lime-300);
    ;       --b8:           var(--lime-200);
    ;       --b9:           var(--lime-100);
    ;       --b10:          var(--lime-50);
    ;     }
    ;     .summer {
    ;       --f0:           var(--red-50);
    ;       --f1:           var(--red-100);
    ;       --f2:           var(--red-200);
    ;       --f3:           var(--red-300);
    ;       --f4:           var(--red-400);
    ;       --f5:           var(--red-500);
    ;       --f6:           var(--red-600);
    ;       --f7:           var(--red-700);
    ;       --f8:           var(--red-800);
    ;       --f9:           var(--red-900);
    ;       --f10:          var(--red-950);
    ;       
    ;       --b0:           var(--red-950);
    ;       --b1:           var(--red-900);
    ;       --b2:           var(--red-800);
    ;       --b3:           var(--red-700);
    ;       --b4:           var(--red-600);
    ;       --b5:           var(--red-500);
    ;       --b6:           var(--red-400);
    ;       --b7:           var(--red-300);
    ;       --b8:           var(--red-200);
    ;       --b9:           var(--red-100);
    ;       --b10:          var(--red-50);
    ;     }
    ;     .autumn {
    ;       --f0:           var(--amber-50);
    ;       --f1:           var(--amber-100);
    ;       --f2:           var(--amber-200);
    ;       --f3:           var(--amber-300);
    ;       --f4:           var(--amber-400);
    ;       --f5:           var(--amber-500);
    ;       --f6:           var(--amber-600);
    ;       --f7:           var(--amber-700);
    ;       --f8:           var(--amber-800);
    ;       --f9:           var(--amber-900);
    ;       --f10:          var(--amber-950);
    ;       
    ;       --b0:           var(--amber-950);
    ;       --b1:           var(--amber-900);
    ;       --b2:           var(--amber-800);
    ;       --b3:           var(--amber-700);
    ;       --b4:           var(--amber-600);
    ;       --b5:           var(--amber-500);
    ;       --b6:           var(--amber-400);
    ;       --b7:           var(--amber-300);
    ;       --b8:           var(--amber-200);
    ;       --b9:           var(--amber-100);
    ;       --b10:          var(--amber-50);
    ;     }
    ;     .winter {
    ;       --f0:           var(--sky-50);
    ;       --f1:           var(--sky-100);
    ;       --f2:           var(--sky-200);
    ;       --f3:           var(--sky-300);
    ;       --f4:           var(--sky-400);
    ;       --f5:           var(--sky-500);
    ;       --f6:           var(--sky-600);
    ;       --f7:           var(--sky-700);
    ;       --f8:           var(--sky-800);
    ;       --f9:           var(--sky-900);
    ;       --f10:          var(--sky-950);
    ;       
    ;       --b0:           var(--sky-950);
    ;       --b1:           var(--sky-900);
    ;       --b2:           var(--sky-800);
    ;       --b3:           var(--sky-700);
    ;       --b4:           var(--sky-600);
    ;       --b5:           var(--sky-500);
    ;       --b6:           var(--sky-400);
    ;       --b7:           var(--sky-300);
    ;       --b8:           var(--sky-200);
    ;       --b9:           var(--sky-100);
    ;       --b10:          var(--sky-50);
    ;     }
    ;   }
    ; }
    ; 
    ; 
    ; /*  part 3: page styling  */
    ;                   
    ;                   
    ; html            { height: 100%;
    ;                   font-family: var(--font-sans) }
    ; body            { margin: 0;
    ;                   height: 100%;
    ;                   color: var(--f0);
    ;                   overflow: auto;
    ;                   position: relative;
    ;                   background: var(--b0);
    ;                   font-feature-settings: normal;
    ;                   font-variation-settings: normal;
    ;                   min-height: 100%;
    ;                   letter-spacing: var(--letter-spacing);
    ;                   line-height: var(--line-height); }
    ; 
    ; 
    ; /*  part 4: utility classes  */
    ; 
    ; 
    ; .break-word     { word-break: break-word; }
    ; .break-all      { word-break: break-all; }
    ; .break-none     { word-break: keep-all; }
    ; .action         { touch-action: manipulation; }
    ; .invisible      { visibility: hidden; }
    ; .hidden         { display: none !important; }
    ; *[hidden]       { display: none !important; }
    ; .jc             { justify-content: center; }
    ; .jb             { justify-content: space-between; }
    ; .ja             { justify-content: space-around; }
    ; .js             { justify-content: start; }
    ; .je             { justify-content: end; }
    ; .as             { align-items: start; }
    ; .af             { align-items: stretch; }
    ; .ae             { align-items: end; }
    ; .ac             { align-items: center; }
    ; .wfc            { width: fit-content; }
    ; .wf             { width: 100%; }
    ; .wn             { width: 0; }
    ; .mwf            { max-width: 100%; }
    ; .mw-page        { max-width: 650px; }
    ; 
    ; .w0             { width: var(--s0); }
    ; .w1             { width: var(--s1); }
    ; .w2             { width: var(--s2); }
    ; .w3             { width: var(--s3); }
    ; .w4             { width: var(--s4); }
    ; .w5             { width: var(--s5); }
    ; .w6             { width: var(--s6); }
    ; .w7             { width: var(--s7); }
    ; .w8             { width: var(--s8); }
    ; .w9             { width: var(--s9); }
    ; .w10            { width: var(--s10); }
    ; .w11            { width: var(--s11); }
    ; .w12            { width: var(--s12); }
    ; .w13            { width: var(--s13); }
    ; .w14            { width: var(--s14); }
    ; .w15            { width: var(--s15); }
    ; .w16            { width: var(--s16); }
    ; .w17            { width: var(--s17); }
    ; .w18            { width: var(--s18); }
    ; .w19            { width: var(--s19); }
    ; .w20            { width: var(--s20); }
    ; .w21            { width: var(--s21); }
    ; .w22            { width: var(--s22); }
    ; .w23            { width: var(--s23); }
    ; .w24            { width: var(--s24); }
    ; .w25            { width: var(--s25); }
    ; .w26            { width: var(--s26); }
    ; .w27            { width: var(--s27); }
    ; .w28            { width: var(--s28); }
    ; .w29            { width: var(--s29); }
    ; .w30            { width: var(--s30); }
    ; .min-w0         { min-width: var(--s0); }
    ; .min-w1         { min-width: var(--s1); }
    ; .min-w2         { min-width: var(--s2); }
    ; .min-w3         { min-width: var(--s3); }
    ; .min-w4         { min-width: var(--s4); }
    ; .min-w5         { min-width: var(--s5); }
    ; .min-w6         { min-width: var(--s6); }
    ; .min-w7         { min-width: var(--s7); }
    ; .min-w8         { min-width: var(--s8); }
    ; .min-w9         { min-width: var(--s9); }
    ; .min-w10        { min-width: var(--s10); }
    ; .min-w11        { min-width: var(--s11); }
    ; .min-w12        { min-width: var(--s12); }
    ; .min-w13        { min-width: var(--s13); }
    ; .min-w14        { min-width: var(--s14); }
    ; .min-w15        { min-width: var(--s15); }
    ; .min-w16        { min-width: var(--s16); }
    ; .min-w17        { min-width: var(--s17); }
    ; .min-w18        { min-width: var(--s18); }
    ; .min-w19        { min-width: var(--s19); }
    ; .min-w20        { min-width: var(--s20); }
    ; .min-w21        { min-width: var(--s21); }
    ; .min-w22        { min-width: var(--s22); }
    ; .min-w23        { min-width: var(--s23); }
    ; .min-w24        { min-width: var(--s24); }
    ; .min-w25        { min-width: var(--s25); }
    ; .min-w26        { min-width: var(--s26); }
    ; .min-w27        { min-width: var(--s27); }
    ; .min-w28        { min-width: var(--s28); }
    ; .min-w29        { min-width: var(--s29); }
    ; .min-w30        { min-width: var(--s30); }
    ; .max-w0         { max-width: var(--s0); }
    ; .max-w1         { max-width: var(--s1); }
    ; .max-w2         { max-width: var(--s2); }
    ; .max-w3         { max-width: var(--s3); }
    ; .max-w4         { max-width: var(--s4); }
    ; .max-w5         { max-width: var(--s5); }
    ; .max-w6         { max-width: var(--s6); }
    ; .max-w7         { max-width: var(--s7); }
    ; .max-w8         { max-width: var(--s8); }
    ; .max-w9         { max-width: var(--s9); }
    ; .max-w10        { max-width: var(--s10); }
    ; .max-w11        { max-width: var(--s11); }
    ; .max-w12        { max-width: var(--s12); }
    ; .max-w13        { max-width: var(--s13); }
    ; .max-w14        { max-width: var(--s14); }
    ; .max-w15        { max-width: var(--s15); }
    ; .max-w16        { max-width: var(--s16); }
    ; .max-w17        { max-width: var(--s17); }
    ; .max-w18        { max-width: var(--s18); }
    ; .max-w19        { max-width: var(--s19); }
    ; .max-w20        { max-width: var(--s20); }
    ; .max-w21        { max-width: var(--s21); }
    ; .max-w22        { max-width: var(--s22); }
    ; .max-w23        { max-width: var(--s23); }
    ; .max-w24        { max-width: var(--s24); }
    ; .max-w25        { max-width: var(--s25); }
    ; .max-w26        { max-width: var(--s26); }
    ; .max-w27        { max-width: var(--s27); }
    ; .max-w28        { max-width: var(--s28); }
    ; .max-w29        { max-width: var(--s29); }
    ; .max-w30        { max-width: var(--s30); }
    ; 
    ; .hf             { height: 100%; }
    ; .mhf            { max-height: 100%; }
    ; .hfc            { height: fit-content; }
    ; 
    ; .h0             { height: var(--s0); }
    ; .h1             { height: var(--s1); }
    ; .h2             { height: var(--s2); }
    ; .h3             { height: var(--s3); }
    ; .h4             { height: var(--s4); }
    ; .h5             { height: var(--s5); }
    ; .h6             { height: var(--s6); }
    ; .h7             { height: var(--s7); }
    ; .h8             { height: var(--s8); }
    ; .h9             { height: var(--s9); }
    ; .h10            { height: var(--s10); }
    ; .h11            { height: var(--s11); }
    ; .h12            { height: var(--s12); }
    ; .h13            { height: var(--s13); }
    ; .h14            { height: var(--s14); }
    ; .h15            { height: var(--s15); }
    ; .h16            { height: var(--s16); }
    ; .h17            { height: var(--s17); }
    ; .h18            { height: var(--s18); }
    ; .h19            { height: var(--s19); }
    ; .h20            { height: var(--s20); }
    ; .h21            { height: var(--s21); }
    ; .h22            { height: var(--s22); }
    ; .h23            { height: var(--s23); }
    ; .h24            { height: var(--s24); }
    ; .h25            { height: var(--s25); }
    ; .h26            { height: var(--s26); }
    ; .h27            { height: var(--s27); }
    ; .h28            { height: var(--s28); }
    ; .h29            { height: var(--s29); }
    ; .h30            { height: var(--s30); }
    ; .min-h0         { min-height: var(--s0); }
    ; .min-h1         { min-height: var(--s1); }
    ; .min-h2         { min-height: var(--s2); }
    ; .min-h3         { min-height: var(--s3); }
    ; .min-h4         { min-height: var(--s4); }
    ; .min-h5         { min-height: var(--s5); }
    ; .min-h6         { min-height: var(--s6); }
    ; .min-h7         { min-height: var(--s7); }
    ; .min-h8         { min-height: var(--s8); }
    ; .min-h9         { min-height: var(--s9); }
    ; .min-h10        { min-height: var(--s10); }
    ; .min-h11        { min-height: var(--s11); }
    ; .min-h12        { min-height: var(--s12); }
    ; .min-h13        { min-height: var(--s13); }
    ; .min-h14        { min-height: var(--s14); }
    ; .min-h15        { min-height: var(--s15); }
    ; .min-h16        { min-height: var(--s16); }
    ; .min-h17        { min-height: var(--s17); }
    ; .min-h18        { min-height: var(--s18); }
    ; .min-h19        { min-height: var(--s19); }
    ; .min-h20        { min-height: var(--s20); }
    ; .min-h21        { min-height: var(--s21); }
    ; .min-h22        { min-height: var(--s22); }
    ; .min-h23        { min-height: var(--s23); }
    ; .min-h24        { min-height: var(--s24); }
    ; .min-h25        { min-height: var(--s25); }
    ; .min-h26        { min-height: var(--s26); }
    ; .min-h27        { min-height: var(--s27); }
    ; .min-h28        { min-height: var(--s28); }
    ; .min-h29        { min-height: var(--s29); }
    ; .min-h30        { min-height: var(--s30); }
    ; .max-h0         { max-height: var(--s0); }
    ; .max-h1         { max-height: var(--s1); }
    ; .max-h2         { max-height: var(--s2); }
    ; .max-h3         { max-height: var(--s3); }
    ; .max-h4         { max-height: var(--s4); }
    ; .max-h5         { max-height: var(--s5); }
    ; .max-h6         { max-height: var(--s6); }
    ; .max-h7         { max-height: var(--s7); }
    ; .max-h8         { max-height: var(--s8); }
    ; .max-h9         { max-height: var(--s9); }
    ; .max-h10        { max-height: var(--s10); }
    ; .max-h11        { max-height: var(--s11); }
    ; .max-h12        { max-height: var(--s12); }
    ; .max-h13        { max-height: var(--s13); }
    ; .max-h14        { max-height: var(--s14); }
    ; .max-h15        { max-height: var(--s15); }
    ; .max-h16        { max-height: var(--s16); }
    ; .max-h17        { max-height: var(--s17); }
    ; .max-h18        { max-height: var(--s18); }
    ; .max-h19        { max-height: var(--s19); }
    ; .max-h20        { max-height: var(--s20); }
    ; .max-h21        { max-height: var(--s21); }
    ; .max-h22        { max-height: var(--s22); }
    ; .max-h23        { max-height: var(--s23); }
    ; .max-h24        { max-height: var(--s24); }
    ; .max-h25        { max-height: var(--s25); }
    ; .max-h26        { max-height: var(--s26); }
    ; .max-h27        { max-height: var(--s27); }
    ; .max-h28        { max-height: var(--s28); }
    ; .max-h29        { max-height: var(--s29); }
    ; .max-h30        { max-height: var(--s30); }
    ; 
    ; .pe-none        { pointer-events: none; }
    ; .pe-auto        { pointer-events: auto; }
    ; 
    ; .mono           { font-family: var(--font-mono); }
    ; .serif          { font-family: var(--font-serif); }
    ; .sans           { font-family: var(--font-sans); }
    ; .italic         { font-style: italic; }
    ; .underline      { text-decoration: underline; }
    ; .no-underline   { text-decoration: none !important; }
    ; .bold           { font-weight: bold; }
    ; .strike         { text-decoration: line-through; }
    ; .pre            { white-space: pre; }
    ; .pre-line       { white-space: pre-line; }
    ; .pre-wrap       { white-space: pre-wrap; }
    ; .nowrap         { white-space: nowrap; }
    ; .tl             { text-align: left; }
    ; .tc             { text-align: center; }
    ; .tr             { text-align: right; }
    ; .contain        { object-fit: contain; }
    ; .middle         { vertical-align: middle; }
    ; .right          { float: right; }
    ; .block          { display: block; }
    ; .inline         { display: inline }
    ; .inline-block   { display: inline-block }
    ; .fc             { display: flex;
    ;                   flex-direction: column; }
    ; .fcr            { display: flex;
    ;                   flex-direction: column-reverse; }
    ; .fcw            { display: flex;
    ;                   flex-direction: column;
    ;                   flex-wrap: wrap; }
    ; .fr             { display: flex;
    ;                   flex-direction: row; }
    ; .frw            { display: flex;
    ;                   flex-direction: row;
    ;                   flex-wrap: wrap; }
    ; .frrw           { display: flex;
    ;                   flex-direction: row-reverse;
    ;                   flex-wrap: wrap; }
    ; .frr            { display: flex;
    ;                   flex-direction: row-reverse; }
    ; .basis-full     { flex-basis: 100%; }
    ; .basis-half     { flex-basis: 50%; flex-shrink: 0; }
    ; .basis-none     { flex-basis: 0%; flex-shrink: 1; }
    ; .shrink-none    { flex-shrink: 0; }
    ; .relative       { position: relative; }
    ; .absolute       { position: absolute; }
    ; .fixed          { position: fixed; }
    ; .sticky         { position: sticky; }
    ; .top0           { top: 0; }
    ; .left0          { left: 0; }
    ; .right0         { right: 0; }
    ; .bottom0        { bottom: 0; }
    ; .z-2            { z-index: -20; }
    ; .z-1            { z-index: -10; }
    ; .z0             { z-index: 0; }
    ; .z1             { z-index: 10; }
    ; .z2             { z-index: 20; }
    ; .grow           { flex-grow: 1; }
    ; 
    ; 
    ; .g0             { gap: var(--s0); }
    ; .g1             { gap: var(--s1); }
    ; .g2             { gap: var(--s2); }
    ; .g3             { gap: var(--s3); }
    ; .g4             { gap: var(--s4); }
    ; .g5             { gap: var(--s5); }
    ; .g6             { gap: var(--s6); }
    ; .g7             { gap: var(--s7); }
    ; .g8             { gap: var(--s8); }
    ; .g9             { gap: var(--s9); }
    ; .g10            { gap: var(--s10); }
    ; .g11            { gap: var(--s11); }
    ; .g12            { gap: var(--s12); }
    ; .g13            { gap: var(--s13); }
    ; .g14            { gap: var(--s14); }
    ; .g15            { gap: var(--s15); }
    ; .g16            { gap: var(--s16); }
    ; .g17            { gap: var(--s17); }
    ; .g18            { gap: var(--s18); }
    ; .g19            { gap: var(--s19); }
    ; .g20            { gap: var(--s20); }
    ; .g21            { gap: var(--s21); }
    ; .g22            { gap: var(--s22); }
    ; .g23            { gap: var(--s23); }
    ; .g24            { gap: var(--s24); }
    ; .g25            { gap: var(--s25); }
    ; .g26            { gap: var(--s26); }
    ; .g27            { gap: var(--s27); }
    ; .g28            { gap: var(--s28); }
    ; .g29            { gap: var(--s29); }
    ; .g30            { gap: var(--s30); }
    ; 
    ; .p-page         { padding: var(--p-page); }
    ; 
    ; .p0             { padding: var(--s0); }
    ; .p1             { padding: var(--s1); }
    ; .p2             { padding: var(--s2); }
    ; .p3             { padding: var(--s3); }
    ; .p4             { padding: var(--s4); }
    ; .p5             { padding: var(--s5); }
    ; .p6             { padding: var(--s6); }
    ; .p7             { padding: var(--s7); }
    ; .p8             { padding: var(--s8); }
    ; .p9             { padding: var(--s9); }
    ; .p10            { padding: var(--s10); }
    ; .p11            { padding: var(--s11); }
    ; .p12            { padding: var(--s12); }
    ; .p13            { padding: var(--s13); }
    ; .p14            { padding: var(--s14); }
    ; .p15            { padding: var(--s15); }
    ; .p16            { padding: var(--s16); }
    ; .p17            { padding: var(--s17); }
    ; .p18            { padding: var(--s18); }
    ; .p19            { padding: var(--s19); }
    ; .p20            { padding: var(--s20); }
    ; .p21            { padding: var(--s21); }
    ; .p22            { padding: var(--s22); }
    ; .p23            { padding: var(--s23); }
    ; .p24            { padding: var(--s24); }
    ; .p25            { padding: var(--s25); }
    ; .p26            { padding: var(--s26); }
    ; .p27            { padding: var(--s27); }
    ; .p28            { padding: var(--s28); }
    ; .p29            { padding: var(--s29); }
    ; .p30            { padding: var(--s30); }
    ; 
    ; .px0            { padding-left: var(--s0);  padding-right: var(--s0);  }
    ; .px1            { padding-left: var(--s1);  padding-right: var(--s1);  }
    ; .px2            { padding-left: var(--s2);  padding-right: var(--s2);  }
    ; .px3            { padding-left: var(--s3);  padding-right: var(--s3);  }
    ; .px4            { padding-left: var(--s4);  padding-right: var(--s4);  }
    ; .px5            { padding-left: var(--s5);  padding-right: var(--s5);  }
    ; .px6            { padding-left: var(--s6);  padding-right: var(--s6);  }
    ; .px7            { padding-left: var(--s7);  padding-right: var(--s7);  }
    ; .px8            { padding-left: var(--s8);  padding-right: var(--s8);  }
    ; .px9            { padding-left: var(--s9);  padding-right: var(--s9);  }
    ; .px10           { padding-left: var(--s10); padding-right: var(--s10); }
    ; .px11           { padding-left: var(--s11); padding-right: var(--s11); }
    ; .px12           { padding-left: var(--s12); padding-right: var(--s12); }
    ; .px13           { padding-left: var(--s13); padding-right: var(--s13); }
    ; .px14           { padding-left: var(--s14); padding-right: var(--s14); }
    ; .px15           { padding-left: var(--s15); padding-right: var(--s15); }
    ; .px16           { padding-left: var(--s16); padding-right: var(--s16); }
    ; .px17           { padding-left: var(--s17); padding-right: var(--s17); }
    ; .px18           { padding-left: var(--s18); padding-right: var(--s18); }
    ; .px19           { padding-left: var(--s19); padding-right: var(--s19); }
    ; .px20           { padding-left: var(--s20); padding-right: var(--s20); }
    ; .px21           { padding-left: var(--s21); padding-right: var(--s21); }
    ; .px22           { padding-left: var(--s22); padding-right: var(--s22); }
    ; .px23           { padding-left: var(--s23); padding-right: var(--s23); }
    ; .px24           { padding-left: var(--s24); padding-right: var(--s24); }
    ; .px25           { padding-left: var(--s25); padding-right: var(--s25); }
    ; .px26           { padding-left: var(--s26); padding-right: var(--s26); }
    ; .px27           { padding-left: var(--s27); padding-right: var(--s27); }
    ; .px28           { padding-left: var(--s28); padding-right: var(--s28); }
    ; .px29           { padding-left: var(--s29); padding-right: var(--s29); }
    ; .px30           { padding-left: var(--s30); padding-right: var(--s30); }
    ; 
    ; .py0            { padding-top: var(--s0);  padding-bottom: var(--s0);  }
    ; .py1            { padding-top: var(--s1);  padding-bottom: var(--s1);  }
    ; .py2            { padding-top: var(--s2);  padding-bottom: var(--s2);  }
    ; .py3            { padding-top: var(--s3);  padding-bottom: var(--s3);  }
    ; .py4            { padding-top: var(--s4);  padding-bottom: var(--s4);  }
    ; .py5            { padding-top: var(--s5);  padding-bottom: var(--s5);  }
    ; .py6            { padding-top: var(--s6);  padding-bottom: var(--s6);  }
    ; .py7            { padding-top: var(--s7);  padding-bottom: var(--s7);  }
    ; .py8            { padding-top: var(--s8);  padding-bottom: var(--s8);  }
    ; .py9            { padding-top: var(--s9);  padding-bottom: var(--s9);  }
    ; .py10           { padding-top: var(--s10); padding-bottom: var(--s10); }
    ; .py11           { padding-top: var(--s11); padding-bottom: var(--s11); }
    ; .py12           { padding-top: var(--s12); padding-bottom: var(--s12); }
    ; .py13           { padding-top: var(--s13); padding-bottom: var(--s13); }
    ; .py14           { padding-top: var(--s14); padding-bottom: var(--s14); }
    ; .py15           { padding-top: var(--s15); padding-bottom: var(--s15); }
    ; .py16           { padding-top: var(--s16); padding-bottom: var(--s16); }
    ; .py17           { padding-top: var(--s17); padding-bottom: var(--s17); }
    ; .py18           { padding-top: var(--s18); padding-bottom: var(--s18); }
    ; .py19           { padding-top: var(--s19); padding-bottom: var(--s19); }
    ; .py20           { padding-top: var(--s20); padding-bottom: var(--s20); }
    ; .py21           { padding-top: var(--s21); padding-bottom: var(--s21); }
    ; .py22           { padding-top: var(--s22); padding-bottom: var(--s22); }
    ; .py23           { padding-top: var(--s23); padding-bottom: var(--s23); }
    ; .py24           { padding-top: var(--s24); padding-bottom: var(--s24); }
    ; .py25           { padding-top: var(--s25); padding-bottom: var(--s25); }
    ; .py26           { padding-top: var(--s26); padding-bottom: var(--s26); }
    ; .py27           { padding-top: var(--s27); padding-bottom: var(--s27); }
    ; .py28           { padding-top: var(--s28); padding-bottom: var(--s28); }
    ; .py29           { padding-top: var(--s29); padding-bottom: var(--s29); }
    ; .py30           { padding-top: var(--s30); padding-bottom: var(--s30); }
    ; 
    ; .pl0            { padding-left: var(--s0); }
    ; .pl1            { padding-left: var(--s1); }
    ; .pl2            { padding-left: var(--s2); }
    ; .pl3            { padding-left: var(--s3); }
    ; .pl4            { padding-left: var(--s4); }
    ; .pl5            { padding-left: var(--s5); }
    ; .pl6            { padding-left: var(--s6); }
    ; .pl7            { padding-left: var(--s7); }
    ; .pl8            { padding-left: var(--s8); }
    ; .pl9            { padding-left: var(--s9); }
    ; .pl10           { padding-left: var(--s10); }
    ; .pl11           { padding-left: var(--s11); }
    ; .pl12           { padding-left: var(--s12); }
    ; .pl13           { padding-left: var(--s13); }
    ; .pl14           { padding-left: var(--s14); }
    ; .pl15           { padding-left: var(--s15); }
    ; .pl16           { padding-left: var(--s16); }
    ; .pl17           { padding-left: var(--s17); }
    ; .pl18           { padding-left: var(--s18); }
    ; .pl19           { padding-left: var(--s19); }
    ; .pl20           { padding-left: var(--s20); }
    ; .pl21           { padding-left: var(--s21); }
    ; .pl22           { padding-left: var(--s22); }
    ; .pl23           { padding-left: var(--s23); }
    ; .pl24           { padding-left: var(--s24); }
    ; .pl25           { padding-left: var(--s25); }
    ; .pl26           { padding-left: var(--s26); }
    ; .pl27           { padding-left: var(--s27); }
    ; .pl28           { padding-left: var(--s28); }
    ; .pl29           { padding-left: var(--s29); }
    ; .pl30           { padding-left: var(--s30); }
    ; 
    ; .pr0            { padding-right: var(--s0); }
    ; .pr1            { padding-right: var(--s1); }
    ; .pr2            { padding-right: var(--s2); }
    ; .pr3            { padding-right: var(--s3); }
    ; .pr4            { padding-right: var(--s4); }
    ; .pr5            { padding-right: var(--s5); }
    ; .pr6            { padding-right: var(--s6); }
    ; .pr7            { padding-right: var(--s7); }
    ; .pr8            { padding-right: var(--s8); }
    ; .pr9            { padding-right: var(--s9); }
    ; .pr10           { padding-right: var(--s10); }
    ; .pr11           { padding-right: var(--s11); }
    ; .pr12           { padding-right: var(--s12); }
    ; .pr13           { padding-right: var(--s13); }
    ; .pr14           { padding-right: var(--s14); }
    ; .pr15           { padding-right: var(--s15); }
    ; .pr16           { padding-right: var(--s16); }
    ; .pr17           { padding-right: var(--s17); }
    ; .pr18           { padding-right: var(--s18); }
    ; .pr19           { padding-right: var(--s19); }
    ; .pr20           { padding-right: var(--s20); }
    ; .pr21           { padding-right: var(--s21); }
    ; .pr22           { padding-right: var(--s22); }
    ; .pr23           { padding-right: var(--s23); }
    ; .pr24           { padding-right: var(--s24); }
    ; .pr25           { padding-right: var(--s25); }
    ; .pr26           { padding-right: var(--s26); }
    ; .pr27           { padding-right: var(--s27); }
    ; .pr28           { padding-right: var(--s28); }
    ; .pr29           { padding-right: var(--s29); }
    ; .pr30           { padding-right: var(--s30); }
    ; 
    ; .pt0            { padding-top: var(--s0); }
    ; .pt1            { padding-top: var(--s1); }
    ; .pt2            { padding-top: var(--s2); }
    ; .pt3            { padding-top: var(--s3); }
    ; .pt4            { padding-top: var(--s4); }
    ; .pt5            { padding-top: var(--s5); }
    ; .pt6            { padding-top: var(--s6); }
    ; .pt7            { padding-top: var(--s7); }
    ; .pt8            { padding-top: var(--s8); }
    ; .pt9            { padding-top: var(--s9); }
    ; .pt10           { padding-top: var(--s10); }
    ; .pt11           { padding-top: var(--s11); }
    ; .pt12           { padding-top: var(--s12); }
    ; .pt13           { padding-top: var(--s13); }
    ; .pt14           { padding-top: var(--s14); }
    ; .pt15           { padding-top: var(--s15); }
    ; .pt16           { padding-top: var(--s16); }
    ; .pt17           { padding-top: var(--s17); }
    ; .pt18           { padding-top: var(--s18); }
    ; .pt19           { padding-top: var(--s19); }
    ; .pt20           { padding-top: var(--s20); }
    ; .pt21           { padding-top: var(--s21); }
    ; .pt22           { padding-top: var(--s22); }
    ; .pt23           { padding-top: var(--s23); }
    ; .pt24           { padding-top: var(--s24); }
    ; .pt25           { padding-top: var(--s25); }
    ; .pt26           { padding-top: var(--s26); }
    ; .pt27           { padding-top: var(--s27); }
    ; .pt28           { padding-top: var(--s28); }
    ; .pt29           { padding-top: var(--s29); }
    ; .pt30           { padding-top: var(--s30); }
    ; 
    ; .pb0            { padding-bottom: var(--s0); }
    ; .pb1            { padding-bottom: var(--s1); }
    ; .pb2            { padding-bottom: var(--s2); }
    ; .pb3            { padding-bottom: var(--s3); }
    ; .pb4            { padding-bottom: var(--s4); }
    ; .pb5            { padding-bottom: var(--s5); }
    ; .pb6            { padding-bottom: var(--s6); }
    ; .pb7            { padding-bottom: var(--s7); }
    ; .pb8            { padding-bottom: var(--s8); }
    ; .pb9            { padding-bottom: var(--s9); }
    ; .pb10           { padding-bottom: var(--s10); }
    ; .pb11           { padding-bottom: var(--s11); }
    ; .pb12           { padding-bottom: var(--s12); }
    ; .pb13           { padding-bottom: var(--s13); }
    ; .pb14           { padding-bottom: var(--s14); }
    ; .pb15           { padding-bottom: var(--s15); }
    ; .pb16           { padding-bottom: var(--s16); }
    ; .pb17           { padding-bottom: var(--s17); }
    ; .pb18           { padding-bottom: var(--s18); }
    ; .pb19           { padding-bottom: var(--s19); }
    ; .pb20           { padding-bottom: var(--s20); }
    ; .pb21           { padding-bottom: var(--s21); }
    ; .pb22           { padding-bottom: var(--s22); }
    ; .pb23           { padding-bottom: var(--s23); }
    ; .pb24           { padding-bottom: var(--s24); }
    ; .pb25           { padding-bottom: var(--s25); }
    ; .pb26           { padding-bottom: var(--s26); }
    ; .pb27           { padding-bottom: var(--s27); }
    ; .pb28           { padding-bottom: var(--s28); }
    ; .pb29           { padding-bottom: var(--s29); }
    ; .pb30           { padding-bottom: var(--s30); }
    ; 
    ; .ma             { margin: auto; }
    ; 
    ; .m0             { margin: var(--s0); }
    ; .m1             { margin: var(--s1); }
    ; .m2             { margin: var(--s2); }
    ; .m3             { margin: var(--s3); }
    ; .m4             { margin: var(--s4); }
    ; .m5             { margin: var(--s5); }
    ; .m6             { margin: var(--s6); }
    ; .m7             { margin: var(--s7); }
    ; .m8             { margin: var(--s8); }
    ; .m9             { margin: var(--s9); }
    ; .m10            { margin: var(--s10); }
    ; .m11            { margin: var(--s11); }
    ; .m12            { margin: var(--s12); }
    ; .m13            { margin: var(--s13); }
    ; .m14            { margin: var(--s14); }
    ; .m15            { margin: var(--s15); }
    ; .m16            { margin: var(--s16); }
    ; .m17            { margin: var(--s17); }
    ; .m18            { margin: var(--s18); }
    ; .m19            { margin: var(--s19); }
    ; .m20            { margin: var(--s20); }
    ; .m21            { margin: var(--s21); }
    ; .m22            { margin: var(--s22); }
    ; .m23            { margin: var(--s23); }
    ; .m24            { margin: var(--s24); }
    ; .m25            { margin: var(--s25); }
    ; .m26            { margin: var(--s26); }
    ; .m27            { margin: var(--s27); }
    ; .m28            { margin: var(--s28); }
    ; .m29            { margin: var(--s29); }
    ; .m30            { margin: var(--s30); }
    ; 
    ; .ml0            { margin-left: var(--s0); }
    ; .ml1            { margin-left: var(--s1); }
    ; .ml2            { margin-left: var(--s2); }
    ; .ml3            { margin-left: var(--s3); }
    ; .ml4            { margin-left: var(--s4); }
    ; .ml5            { margin-left: var(--s5); }
    ; .ml6            { margin-left: var(--s6); }
    ; .ml7            { margin-left: var(--s7); }
    ; .ml8            { margin-left: var(--s8); }
    ; .ml9            { margin-left: var(--s9); }
    ; .ml10           { margin-left: var(--s10); }
    ; .ml11           { margin-left: var(--s11); }
    ; .ml12           { margin-left: var(--s12); }
    ; .ml13           { margin-left: var(--s13); }
    ; .ml14           { margin-left: var(--s14); }
    ; .ml15           { margin-left: var(--s15); }
    ; .ml16           { margin-left: var(--s16); }
    ; .ml17           { margin-left: var(--s17); }
    ; .ml18           { margin-left: var(--s18); }
    ; .ml19           { margin-left: var(--s19); }
    ; .ml20           { margin-left: var(--s20); }
    ; .ml21           { margin-left: var(--s21); }
    ; .ml22           { margin-left: var(--s22); }
    ; .ml23           { margin-left: var(--s23); }
    ; .ml24           { margin-left: var(--s24); }
    ; .ml25           { margin-left: var(--s25); }
    ; .ml26           { margin-left: var(--s26); }
    ; .ml27           { margin-left: var(--s27); }
    ; .ml28           { margin-left: var(--s28); }
    ; .ml29           { margin-left: var(--s29); }
    ; .ml30           { margin-left: var(--s30); }
    ; 
    ; .mr0            { margin-right: var(--s0); }
    ; .mr1            { margin-right: var(--s1); }
    ; .mr2            { margin-right: var(--s2); }
    ; .mr3            { margin-right: var(--s3); }
    ; .mr4            { margin-right: var(--s4); }
    ; .mr5            { margin-right: var(--s5); }
    ; .mr6            { margin-right: var(--s6); }
    ; .mr7            { margin-right: var(--s7); }
    ; .mr8            { margin-right: var(--s8); }
    ; .mr9            { margin-right: var(--s9); }
    ; .mr10           { margin-right: var(--s10); }
    ; .mr11           { margin-right: var(--s11); }
    ; .mr12           { margin-right: var(--s12); }
    ; .mr13           { margin-right: var(--s13); }
    ; .mr14           { margin-right: var(--s14); }
    ; .mr15           { margin-right: var(--s15); }
    ; .mr16           { margin-right: var(--s16); }
    ; .mr17           { margin-right: var(--s17); }
    ; .mr18           { margin-right: var(--s18); }
    ; .mr19           { margin-right: var(--s19); }
    ; .mr20           { margin-right: var(--s20); }
    ; .mr21           { margin-right: var(--s21); }
    ; .mr22           { margin-right: var(--s22); }
    ; .mr23           { margin-right: var(--s23); }
    ; .mr24           { margin-right: var(--s24); }
    ; .mr25           { margin-right: var(--s25); }
    ; .mr26           { margin-right: var(--s26); }
    ; .mr27           { margin-right: var(--s27); }
    ; .mr28           { margin-right: var(--s28); }
    ; .mr29           { margin-right: var(--s29); }
    ; .mr30           { margin-right: var(--s30); }
    ; 
    ; .mt0            { margin-top: var(--s0); }
    ; .mt1            { margin-top: var(--s1); }
    ; .mt2            { margin-top: var(--s2); }
    ; .mt3            { margin-top: var(--s3); }
    ; .mt4            { margin-top: var(--s4); }
    ; .mt5            { margin-top: var(--s5); }
    ; .mt6            { margin-top: var(--s6); }
    ; .mt7            { margin-top: var(--s7); }
    ; .mt8            { margin-top: var(--s8); }
    ; .mt9            { margin-top: var(--s9); }
    ; .mt10           { margin-top: var(--s10); }
    ; .mt11           { margin-top: var(--s11); }
    ; .mt12           { margin-top: var(--s12); }
    ; .mt13           { margin-top: var(--s13); }
    ; .mt14           { margin-top: var(--s14); }
    ; .mt15           { margin-top: var(--s15); }
    ; .mt16           { margin-top: var(--s16); }
    ; .mt17           { margin-top: var(--s17); }
    ; .mt18           { margin-top: var(--s18); }
    ; .mt19           { margin-top: var(--s19); }
    ; .mt20           { margin-top: var(--s20); }
    ; .mt21           { margin-top: var(--s21); }
    ; .mt22           { margin-top: var(--s22); }
    ; .mt23           { margin-top: var(--s23); }
    ; .mt24           { margin-top: var(--s24); }
    ; .mt25           { margin-top: var(--s25); }
    ; .mt26           { margin-top: var(--s26); }
    ; .mt27           { margin-top: var(--s27); }
    ; .mt28           { margin-top: var(--s28); }
    ; .mt29           { margin-top: var(--s29); }
    ; .mt30           { margin-top: var(--s30); }
    ; 
    ; .mb0            { margin-bottom: var(--s0); }
    ; .mb1            { margin-bottom: var(--s1); }
    ; .mb2            { margin-bottom: var(--s2); }
    ; .mb3            { margin-bottom: var(--s3); }
    ; .mb4            { margin-bottom: var(--s4); }
    ; .mb5            { margin-bottom: var(--s5); }
    ; .mb6            { margin-bottom: var(--s6); }
    ; .mb7            { margin-bottom: var(--s7); }
    ; .mb8            { margin-bottom: var(--s8); }
    ; .mb9            { margin-bottom: var(--s9); }
    ; .mb10           { margin-bottom: var(--s10); }
    ; .mb11           { margin-bottom: var(--s11); }
    ; .mb12           { margin-bottom: var(--s12); }
    ; .mb13           { margin-bottom: var(--s13); }
    ; .mb14           { margin-bottom: var(--s14); }
    ; .mb15           { margin-bottom: var(--s15); }
    ; .mb16           { margin-bottom: var(--s16); }
    ; .mb17           { margin-bottom: var(--s17); }
    ; .mb18           { margin-bottom: var(--s18); }
    ; .mb19           { margin-bottom: var(--s19); }
    ; .mb20           { margin-bottom: var(--s20); }
    ; .mb21           { margin-bottom: var(--s21); }
    ; .mb22           { margin-bottom: var(--s22); }
    ; .mb23           { margin-bottom: var(--s23); }
    ; .mb24           { margin-bottom: var(--s24); }
    ; .mb25           { margin-bottom: var(--s25); }
    ; .mb26           { margin-bottom: var(--s26); }
    ; .mb27           { margin-bottom: var(--s27); }
    ; .mb28           { margin-bottom: var(--s28); }
    ; .mb29           { margin-bottom: var(--s29); }
    ; .mb30           { margin-bottom: var(--s30); }
    ; 
    ; .o0             { opacity: 0%; }
    ; .o1             { opacity: 10%; }
    ; .o2             { opacity: 20%; }
    ; .o3             { opacity: 30%; }
    ; .o4             { opacity: 40%; }
    ; .o5             { opacity: 50%; }
    ; .o6             { opacity: 60%; }
    ; .o7             { opacity: 70%; }
    ; .o8             { opacity: 80%; }
    ; .o9             { opacity: 90%; }
    ; .o10            { opacity: 100%; }
    ; 
    ; .scroll-y       { overflow-y: auto; }
    ; .scroll-x       { overflow-x: auto; }
    ; .scroll-none    { overflow: hidden; }
    ; 
    ; ::-webkit-scrollbar              { width: 12px; }
    ; ::-webkit-scrollbar:horizontal   { height: 12px; }
    ; ::-webkit-scrollbar-thumb {
    ;   background-color: var(--b4);
    ;   filter: brightness(var(--percent-scale));
    ; }
    ; ::-webkit-scrollbar-track {
    ;   background: var(--b1);
    ;   filter: brightness(var(--percent-scale));
    ; }
    ; ::-webkit-scrollbar-corner {
    ;   background: var(--b1);
    ;   filter: brightness(var(--percent-scale));
    ; }
    ; 
    ; .f-4            { color: var(--f-4); }
    ; .f-3            { color: var(--f-3); }
    ; .f-2            { color: var(--f-2); }
    ; .f-1            { color: var(--f-1); }
    ; 
    ; .f0             { color: var(--f0); }
    ; .f1             { color: var(--f1); }
    ; .f2             { color: var(--f2); }
    ; .f3             { color: var(--f3); }
    ; .f4             { color: var(--f4); }
    ; .f5             { color: var(--f5); }
    ; .f6             { color: var(--f6); }
    ; .f7             { color: var(--f7); }
    ; .f8             { color: var(--f8); }
    ; .f9             { color: var(--f9); }
    ; .f10            { color: var(--f10); }
    ; 
    ; .b-none         { background-color: none; }
    ; 
    ; .b-4            { background-color: var(--b-4); }
    ; .b-3            { background-color: var(--b-3); }
    ; .b-2            { background-color: var(--b-2); }
    ; .b-1            { background-color: var(--b-1); }
    ; 
    ; .b0             { background-color: var(--b0); }
    ; .b1             { background-color: var(--b1); }
    ; .b2             { background-color: var(--b2); }
    ; .b3             { background-color: var(--b3); }
    ; .b4             { background-color: var(--b4); }
    ; .b5             { background-color: var(--b5); }
    ; .b6             { background-color: var(--b6); }
    ; .b7             { background-color: var(--b7); }
    ; .b8             { background-color: var(--b8); }
    ; .b9             { background-color: var(--b9); }
    ; .b10            { background-color: var(--b10); }
    ; 
    ; .fs-4           { font-size: 0.6rem; }
    ; .fs-3           { font-size: 0.7rem; }
    ; .fs-2           { font-size: 0.8rem; }
    ; .fs-1           { font-size: 0.9rem; }
    ; .fs-0           { font-size: 1rem; }
    ; .fs0            { font-size: 1rem; }
    ; .fs1            { font-size: 1.15rem; }
    ; .fs2            { font-size: 1.3rem; }
    ; .fs3            { font-size: 1.45rem; }
    ; .fs4            { font-size: 1.6rem; }
    ; .fs5            { font-size: 2rem; }
    ; .fs6            { font-size: 2.4rem; }
    ; .fs7            { font-size: 2.8rem; }
    ; .fs8            { font-size: 3.4rem; }
    ; .fs9            { font-size: 4.4rem; }
    ; .fs10           { font-size: 5.4rem; }
    ; 
    ; .lh0            { line-height: 1; }
    ; .lh1            { line-height: 1.1; }
    ; .lh2            { line-height: 1.2; }
    ; .lh3            { line-height: 1.3; }
    ; .lh4            { line-height: 1.4; }
    ; .lh5            { line-height: 1.5; }
    ; .lh6            { line-height: 1.6; }
    ; .lh7            { line-height: 1.7; }
    ; .lh8            { line-height: 1.8; }
    ; .lh9            { line-height: 1.9; }
    ; .lh10           { line-height: 2; }
    ; 
    ; .bd0            { border: none; }
    ; .bd1            { border: 1px solid var(--f5); }
    ; .bd2            { border: 2px solid var(--f5); }
    ; .bd3            { border: 4px solid var(--f5); }
    ; 
    ; .bdt0           { border-top: none; }
    ; .bdt1           { border-top: 1px solid var(--f5); }
    ; .bdt2           { border-top: 2px solid var(--f5); }
    ; .bdt3           { border-top: 4px solid var(--f5); }
    ; 
    ; .bdb0           { border-bottom: none; }
    ; .bdb1           { border-bottom: 1px solid var(--f5); }
    ; .bdb2           { border-bottom: 2px solid var(--f5); }
    ; .bdb3           { border-bottom: 4px solid var(--f5); }
    ; 
    ; .bdl0           { border-left: none; }
    ; .bdl1           { border-left: 1px solid var(--f5); }
    ; .bdl2           { border-left: 2px solid var(--f5); }
    ; .bdl3           { border-left: 4px solid var(--f5); }
    ; 
    ; .bdr0           { border-right: none; }
    ; .bdr1           { border-right: 1px solid var(--f5); }
    ; .bdr2           { border-right: 2px solid var(--f5); }
    ; .bdr3           { border-right: 4px solid var(--f5); }
    ; 
    ; .br0            { border-radius: var(--s0); }
    ; .br1            { border-radius: var(--s1); }
    ; .br2            { border-radius: var(--s2); }
    ; .br3            { border-radius: var(--s3); }
    ; .br4            { border-radius: var(--s4); }
    ; .br5            { border-radius: var(--s5); }
    ; .br6            { border-radius: var(--s6); }
    ; .br7            { border-radius: var(--s7); }
    ; .br8            { border-radius: var(--s8); }
    ; .br9            { border-radius: var(--s9); }
    ; .br10           { border-radius: var(--s10); }
    ; 
    ; .btrr0          { border-top-right-radius: var(--s0); }
    ; .btrr1          { border-top-right-radius: var(--s1); }
    ; .btrr2          { border-top-right-radius: var(--s2); }
    ; .btrr3          { border-top-right-radius: var(--s3); }
    ; .btrr4          { border-top-right-radius: var(--s4); }
    ; .btrr5          { border-top-right-radius: var(--s5); }
    ; .btrr6          { border-top-right-radius: var(--s6); }
    ; .btrr7          { border-top-right-radius: var(--s7); }
    ; .btrr8          { border-top-right-radius: var(--s8); }
    ; .btrr9          { border-top-right-radius: var(--s9); }
    ; .btrr10         { border-top-right-radius: var(--s10); }
    ; 
    ; .btlr0          { border-top-left-radius: var(--s0); }
    ; .btlr1          { border-top-left-radius: var(--s1); }
    ; .btlr2          { border-top-left-radius: var(--s2); }
    ; .btlr3          { border-top-left-radius: var(--s3); }
    ; .btlr4          { border-top-left-radius: var(--s4); }
    ; .btlr5          { border-top-left-radius: var(--s5); }
    ; .btlr6          { border-top-left-radius: var(--s6); }
    ; .btlr7          { border-top-left-radius: var(--s7); }
    ; .btlr8          { border-top-left-radius: var(--s8); }
    ; .btlr9          { border-top-left-radius: var(--s9); }
    ; .btlr10         { border-top-left-radius: var(--s10); }
    ; 
    ; .bbrr0          { border-bottom-right-radius: var(--s0); }
    ; .bbrr1          { border-bottom-right-radius: var(--s1); }
    ; .bbrr2          { border-bottom-right-radius: var(--s2); }
    ; .bbrr3          { border-bottom-right-radius: var(--s3); }
    ; .bbrr4          { border-bottom-right-radius: var(--s4); }
    ; .bbrr5          { border-bottom-right-radius: var(--s5); }
    ; .bbrr6          { border-bottom-right-radius: var(--s6); }
    ; .bbrr7          { border-bottom-right-radius: var(--s7); }
    ; .bbrr8          { border-bottom-right-radius: var(--s8); }
    ; .bbrr9          { border-bottom-right-radius: var(--s9); }
    ; .bbrr10         { border-bottom-right-radius: var(--s10); }
    ; 
    ; .bblr0          { border-bottom-left-radius: var(--s0); }
    ; .bblr1          { border-bottom-left-radius: var(--s1); }
    ; .bblr2          { border-bottom-left-radius: var(--s2); }
    ; .bblr3          { border-bottom-left-radius: var(--s3); }
    ; .bblr4          { border-bottom-left-radius: var(--s4); }
    ; .bblr5          { border-bottom-left-radius: var(--s5); }
    ; .bblr6          { border-bottom-left-radius: var(--s6); }
    ; .bblr7          { border-bottom-left-radius: var(--s7); }
    ; .bblr8          { border-bottom-left-radius: var(--s8); }
    ; .bblr9          { border-bottom-left-radius: var(--s9); }
    ; .bblr10         { border-bottom-left-radius: var(--s10); }
    ; 
    ; .bc-4           { border-color: var(--f-4); }
    ; .bc-3           { border-color: var(--f-3); }
    ; .bc-2           { border-color: var(--f-2); }
    ; .bc-1           { border-color: var(--f-1); }
    ; .bc0            { border-color: var(--f0); }
    ; .bc1            { border-color: var(--f1); }
    ; .bc2            { border-color: var(--f2); }
    ; .bc3            { border-color: var(--f3); }
    ; .bc4            { border-color: var(--f4); }
    ; .bc5            { border-color: var(--f5); }
    ; .bc6            { border-color: var(--f6); }
    ; .bc7            { border-color: var(--f7); }
    ; .bc8            { border-color: var(--f8); }
    ; .bc9            { border-color: var(--f9); }
    ; .bc10           { border-color: var(--f10); }
    ; 
    ; .toggled        { background: var(--f0);
    ;                   color: var(--b0); }
    ; .toggled.b0     { background-color: var(--f0); }
    ; .toggled.b1     { background-color: var(--f1); }
    ; .toggled.b2     { background-color: var(--f2); }
    ; .toggled.b3     { background-color: var(--f3); }
    ; .toggled.b4     { background-color: var(--f4); }
    ; .toggled.b-1    { background-color: var(--f-1); }
    ; .toggled.b-2    { background-color: var(--f-2); }
    ; .toggled.b-3    { background-color: var(--f-3); }
    ; .toggled.b-4    { background-color: var(--f-4); }
    ; .toggled.f0     { color: var(--b0); }
    ; .toggled.f1     { color: var(--b1); }
    ; .toggled.f2     { color: var(--b2); }
    ; .toggled.f3     { color: var(--b3); }
    ; .toggled.f4     { color: var(--b4); }
    ; .toggled.f-1    { color: var(--b-1); }
    ; .toggled.f-2    { color: var(--b-2); }
    ; .toggled.f-3    { color: var(--b-3); }
    ; .toggled.f-4    { color: var(--b-4); }
    ; .active         { filter: invert(var(--active-offset)); }
    ; *:disabled      { opacity: 0.4; cursor: not-allowed; pointer-events: none; transition: opacity 0.3s ease; }
    ; .disabled       { opacity: 0.4; cursor: not-allowed; pointer-events: none; transition: opacity 0.3s ease; }
    ; 
    ; 
    ; /* desktop hovers */
    ; 
    ; 
    ; @media (min-width: 700px) {
    ;   .hover:hover         { filter: invert(17%); }
    ;   .hover-fg:hover      { color: var(--f0); }
    ;   .hover-bd:hover      { border-color: var(--f0); }
    ;   .hover-f:hover       { color: var(--f0); border-color: var(--f0); }
    ;   .hover.active:hover  { filter: invert(25%); }
    ;   .hover:disabled      { filter: none; }
    ; }
    ; 
    ; .focus:focus {
    ;   outline: none;
    ;   box-shadow: inset  1px  1px var(--focus-color),
    ;               inset -1px -1px var(--focus-color);
    ; }
    ; 
    ; .pointer        { cursor: pointer; }
    ; .grabber        { cursor: grab; }
    ; .no-select      { user-select: none;
    ;                   -webkit-user-select: none; }
    ; .page {
    ;   padding: var(--p-page);
    ;   margin: auto;
    ;   max-width: 650px;
    ; }
    ; .page-wide {
    ;   padding: var(--p-page);
    ;   margin: auto;
    ;   max-width: 880px;
    ; }
    ; .prose h1 {
    ;   font-size: 1.45em;
    ;   margin: 1rem 0;
    ; }
    ; .prose h2 {
    ;   font-size: 1.3em;
    ;   margin: 1rem 0;
    ; }
    ; .prose h3 {
    ;   font-size: 1.15em;
    ;   margin: 1rem 0;
    ; }
    ; .prose h1, .prose h2, .prose h3 {
    ;   font-weight: bold;
    ; }
    ; .prose p {
    ;   margin: 1rem 0;
    ;   line-height: 1.5;
    ;   overflow-wrap: break-word;
    ; }
    ; .prose img {
    ;   margin: 1rem 0;
    ;   max-width: 100%;
    ;   display: block;
    ;   max-height: 350px;
    ; }
    ; .prose details {
    ;   margin: 1rem 0;
    ; }
    ; .prose a {
    ;   text-decoration: underline;
    ; }
    ; .prose blockquote {
    ;   margin: 1rem 0;
    ;   margin-left: 10px;
    ;   border-left: 2px solid var(--b3);
    ;   padding: 4px;
    ;   padding-left: 12px;
    ;   color: var(--f2);
    ; }
    ; .prose pre {
    ;   font-family: var(--font-mono);
    ;   font-size: calc(1em * var(--mono-scale));
    ;   overflow-x: auto;
    ;   width: 100%;
    ;   display: block;
    ;   padding: 8px;
    ;   margin: 1rem 0;
    ;   background-color: var(--b1);
    ; }
    ; .prose code {
    ;   font-family: var(--font-mono);
    ;   font-size: calc(1em * var(--mono-scale));
    ;   color: var(--f2);
    ; }
    ; .prose hr {
    ;   margin: 2rem 0;
    ; }
    ; .prose > ul,
    ; .prose > ol {
    ;   margin: 1rem 0;
    ; }
    ; .prose ul,
    ; .prose ol {
    ;   padding-left: 29px;
    ;   margin: 0;
    ; }
    ; .prose ul p,
    ; .prose ol p {
    ;   margin: 0.5rem 0;
    ;   line-height: calc(calc(1 + var(--line-height)) / 2);
    ; }
    ; .prose ul p:first-child,
    ; .prose ol p:first-child {
    ;   margin: 0;
    ;   margin-bottom: 0.5rem;
    ; }
    ; .prose ul p:last-child,
    ; .prose ol p:last-child {
    ;   margin: 0;
    ;   margin-top: 0.5rem;
    ; }
    ; .prose li {
    ;   margin: 0.5rem 0;
    ; }
    ; .prose ul ul,
    ; .prose ol ul,
    ; .prose ul ol,
    ; .prose ol ol {
    ;   margin-bottom: 0;
    ; }
    ; .prose summary {
    ;   user-select: none;
    ;   -webkit-user-select: none;
    ; }
    ; .prose table {
    ;   border-collapse: collapse;
    ;   border-radius: 0.3em;
    ;   th, td {
    ;     border: 1px solid var(--f3);
    ;     padding: 0.5em 1em;
    ;   }
    ; }
    ; 
    ; 
    ; /* part 5: form/input/actionable styling */
    ; 
    ; 
    ; .loader { position: relative; display: flex; }
    ; .loading {
    ;   position: absolute;
    ;   top: 50%;
    ;   left: 50%;
    ;   transform: translate(-50%, -50%);
    ;   pointer-events: none;
    ; }
    ; .loader .loading {
    ;   opacity: 0;
    ;   transition: opacity 300ms;
    ; }
    ; .is-loading.loader {
    ;   pointer-events: none;
    ; }
    ; .is-loading .loader .loading,
    ; .loader.is-loading .loading {
    ;   opacity: 1;
    ; }
    ; .loader .loaded {
    ;   opacity: 1;
    ;   transition: opacity 300ms;
    ; }
    ; .is-loading .loader .loaded,
    ; .loader.is-loading .loaded {
    ;   opacity: 0;
    ; }
    ; .is-requesting {
    ;   animation: requestPulse 2s ease-out infinite;
    ; }
    ; @keyframes requestPulse {
    ;   0% {
    ;     filter: invert(0%);
    ;   }
    ;   50% {
    ;     filter: invert(100%);
    ;   }
    ;   100% {
    ;     filter: invert(0%);
    ;   }
    ; }
    ; ::placeholder {
    ;   color: var(--f5);
    ;   opacity: 0.5;
    ; }
    ; input[type="checkbox"] {
    ;   appearance: none;
    ;   -webkit-appearance: none;
    ;   width: 1em;
    ;   height: 1em;
    ;   border: 1.5px solid currentColor;
    ;   border-radius: 20%;
    ;   display: inline-block;
    ;   vertical-align: middle;
    ;   cursor: pointer;
    ;   position: relative;
    ; }
    ; input[type="checkbox"]:checked::before {
    ;   content: '';
    ;   position: absolute;
    ;   top: 50%;
    ;   left: 50%;
    ;   width: 0.5em;
    ;   height: 0.5em;
    ;   background: currentColor;
    ;   border-radius: 20%;
    ;   transform: translate(-50%, -50%);
    ; }
    ; input[type="radio"] {
    ;   appearance: none;
    ;   -webkit-appearance: none;
    ;   width: 1em;
    ;   height: 1em;
    ;   border: 1.5px solid currentColor;
    ;   border-radius: 50%;
    ;   display: inline-block;
    ;   vertical-align: middle;
    ;   cursor: pointer;
    ;   position: relative;
    ; }
    ; input[type="radio"]:checked::before {
    ;   content: '';
    ;   position: absolute;
    ;   top: 50%;
    ;   left: 50%;
    ;   width: 0.5em;
    ;   height: 0.5em;
    ;   background: currentColor;
    ;   border-radius: 50%;
    ;   transform: translate(-50%, -50%);
    ; }
    ; input[type=range] {
    ;   -webkit-appearance: none;
    ;   appearance: none;
    ;   width: 100%;
    ;   height: 5px;
    ;   background: var(--f4);
    ;   outline: none;
    ;   border-radius: 5px;
    ; }
    ; /* Style the slider thumb */
    ; input[type=range]::-webkit-slider-thumb {
    ;   -webkit-appearance: none;
    ;   appearance: none;
    ;   width: 0.8em;
    ;   height: 0.8em;
    ;   background: var(--f0);
    ;   cursor: pointer;
    ;   border-radius: 50%;
    ;   border: none;
    ; }
    ; input[type=range]::-moz-range-thumb {
    ;   width: 0.8em;
    ;   height: 0.8em;
    ;   background: var(--f0);
    ;   cursor: pointer;
    ;   border-radius: 50%;
    ;   border: none;
    ; }
    ; details summary.no-arrow::-webkit-details-marker,
    ; details summary.no-arrow::marker {
    ;   display: none;
    ;   content: "";
    ; }
  ==
--
