|%
++  col-split
  '''
  class ColSplit extends HTMLElement {
      constructor() {
          super();
  
          // Attach Shadow DOM
          this.attachShadow({ mode: 'open' });
  
          // Add template for styling and structure
          this.shadowRoot.innerHTML = `
              <style>
                  :host {
                      display: block;
                      width: 100%;
                      height: 100%;
                  }
                  .container {
                      display: flex;
                      flex-direction: column;
                      width: 100%;
                      height: 100%;
                  }
                  .pane {
                      box-sizing: border-box;
                      overflow: auto;
                  }
              </style>
              <div class="container">
                  <div class="pane top" style="flex-basis: auto;" data-slot="top"><slot name="top"></slot></div>
                  <div class="pane bottom" style="flex-basis: auto;" data-slot="bottom"><slot name="bottom"></slot></div>
              </div>
          `;
  
          this.container = this.shadowRoot.querySelector(".container");
          this.topPane = this.shadowRoot.querySelector(".top");
          this.bottomPane = this.shadowRoot.querySelector(".bottom");
      }
  
      connectedCallback() {
          this.updatePanes();
      }
  
      updatePanes() {
          const topSlot = this.querySelector('[slot="top"]');
          const bottomSlot = this.querySelector('[slot="bottom"]');
  
          const topHeight = topSlot ? topSlot.getAttribute('height') : null;
          const bottomHeight = bottomSlot ? bottomSlot.getAttribute('height') : null;
  
          if (topHeight) {
              this.topPane.style.flexBasis = topHeight;
              this.bottomPane.style.flexBasis = `calc(100% - ${topHeight})`;
          } else if (bottomHeight) {
              this.bottomPane.style.flexBasis = bottomHeight;
              this.topPane.style.flexBasis = `calc(100% - ${bottomHeight})`;
          } else {
              this.topPane.style.flexBasis = '50%';
              this.bottomPane.style.flexBasis = '50%';
          }
      }
  }
  
  // Define the custom element
  customElements.define('col-split', ColSplit);
  '''
::
++  row-split
  '''
  class RowSplit extends HTMLElement {
      constructor() {
          super();
  
          // Attach Shadow DOM
          this.attachShadow({ mode: 'open' });
  
          // Add template for styling and structure
          this.shadowRoot.innerHTML = `
              <style>
                  :host {
                      display: block;
                      width: 100%;
                      height: 100%;
                  }
                  .container {
                      display: flex;
                      width: 100%;
                      height: 100%;
                  }
                  .pane {
                      box-sizing: border-box;
                      overflow: auto;
                  }
              </style>
              <div class="container">
                  <div class="pane left" style="flex-basis: auto;" data-slot="left"><slot name="left"></slot></div>
                  <div class="pane right" style="flex-basis: auto;" data-slot="right"><slot name="right"></slot></div>
              </div>
          `;
  
          this.container = this.shadowRoot.querySelector(".container");
          this.leftPane = this.shadowRoot.querySelector(".left");
          this.rightPane = this.shadowRoot.querySelector(".right");
      }
  
      connectedCallback() {
          this.updatePanes();
      }
  
      updatePanes() {
          const leftSlot = this.querySelector('[slot="left"]');
          const rightSlot = this.querySelector('[slot="right"]');
  
          const leftWidth = leftSlot ? leftSlot.getAttribute('width') : null;
          const rightWidth = rightSlot ? rightSlot.getAttribute('width') : null;
  
          if (leftWidth) {
              this.leftPane.style.flexBasis = leftWidth;
              this.rightPane.style.flexBasis = `calc(100% - ${leftWidth})`;
          } else if (rightWidth) {
              this.rightPane.style.flexBasis = rightWidth;
              this.leftPane.style.flexBasis = `calc(100% - ${rightWidth})`;
          } else {
              this.leftPane.style.flexBasis = '50%';
              this.rightPane.style.flexBasis = '50%';
          }
      }
  }
  
  // Define the custom element
  customElements.define('row-split', RowSplit);
  '''
::
++  side-bar
  '''
   class SideBar extends HTMLElement {
       constructor() {
           super();
   
           // Attach Shadow DOM
           this.attachShadow({ mode: 'open' });
   
           // Add template for styling and structure
           this.shadowRoot.innerHTML = `
               <style>
                   :host {
                       display: block;
                       height: 100vh; /* Full viewport height */
                   }
                   .container {
                       display: flex;
                       width: 100%;
                       height: 100%;
                   }
                   .half {
                       display: flex;
                       align-items: center;
                       justify-content: center;
                       box-sizing: border-box; /* Include padding and border in width/height */
                   }
                   .divider {
                       width: 2px;
                       cursor: col-resize;
                       height: 100%;
                       background-color: gray;
                       position: relative;
                   }
                   .hidden {
                       display: none; /* Hide the element completely */
                   }
               </style>
               <div class="container">
                   <div class="half left" style="flex: 1;"><slot name="left"></slot></div>
                   <div class="divider"></div>
                   <div class="half right" style="flex: 1;"><slot name="right"></slot></div>
               </div>
           `;
   
           this.divider = this.shadowRoot.querySelector(".divider");
           this.leftPanel = this.shadowRoot.querySelector(".left");
           this.rightPanel = this.shadowRoot.querySelector(".right");
       }
   
       static get observedAttributes() {
           return ['hide', 'side', 'min-left', 'max-left', 'min-right', 'max-right', 'initial', 'divider-style'];
       }
   
       connectedCallback() {
           this.minLeft = this.getAttribute('min-left') || '0';
           this.maxLeft = this.getAttribute('max-left') || '100%';
           this.minRight = this.getAttribute('min-right') || '0';
           this.maxRight = this.getAttribute('max-right') || '100%';
           this.initial = this.getAttribute('initial') || '50%';
   
           this.applyDividerStyle();
   
           const containerWidth = this.shadowRoot.host.clientWidth;
           this.minLeftPx = this.convertToPixels(this.minLeft, containerWidth);
           this.maxLeftPx = this.convertToPixels(this.maxLeft, containerWidth);
           this.minRightPx = this.convertToPixels(this.minRight, containerWidth);
           this.maxRightPx = this.convertToPixels(this.maxRight, containerWidth);
           this.initialPx = this.convertToPixels(this.initial, containerWidth);
   
           if (this.minLeftPx + this.minRightPx > containerWidth) {
               const scale = containerWidth / (this.minLeftPx + this.minRightPx);
               this.minLeftPx *= scale;
               this.minRightPx *= scale;
           }
   
           this.setInitialWidths(containerWidth);
           this.handleHide();
           this.initDivider();
       }
   
       attributeChangedCallback(name, oldValue, newValue) {
           if (name === 'hide' || name === 'side') {
               this.handleHide();
           }
       }
   
       setInitialWidths(containerWidth) {
           let initialLeftWidth = Math.max(this.minLeftPx, Math.min(this.initialPx, this.maxLeftPx));
           let initialRightWidth = containerWidth - initialLeftWidth - 3;
   
           if (initialRightWidth < this.minRightPx) {
               initialRightWidth = this.minRightPx;
               initialLeftWidth = containerWidth - initialRightWidth - 3;
           } else if (initialRightWidth > this.maxRightPx) {
               initialRightWidth = this.maxRightPx;
               initialLeftWidth = containerWidth - initialRightWidth - 3;
           }
   
           const leftFlex = initialLeftWidth / containerWidth;
           const rightFlex = initialRightWidth / containerWidth;
   
           this.leftPanel.style.flex = leftFlex.toString();
           this.rightPanel.style.flex = rightFlex.toString();
       }
   
       handleHide() {
           const hide = this.hasAttribute('hide');
           const side = this.getAttribute('side') || 'left';
   
           // Reset visibility
           this.leftPanel.classList.remove('hidden');
           this.rightPanel.classList.remove('hidden');
           this.divider.classList.remove('hidden');
   
           // Apply hiding logic
           if (hide && side === 'left') {
               this.leftPanel.classList.add('hidden');
               this.divider.classList.add('hidden');
               this.rightPanel.style.flex = '1';
           } else if (hide && side === 'right') {
               this.rightPanel.classList.add('hidden');
               this.divider.classList.add('hidden');
               this.leftPanel.style.flex = '1';
           }
       }
   
       applyDividerStyle() {
           const dividerStyle = this.getAttribute('divider-style');
           if (dividerStyle) {
               const styleObj = this.parseStyleString(dividerStyle);
               Object.entries(styleObj).forEach(([key, value]) => {
                   this.divider.style[key] = value;
               });
           }
       }
   
       parseStyleString(styleString) {
           return styleString.split(';').reduce((acc, style) => {
               const [key, value] = style.split(':').map(s => s.trim());
               if (key && value) acc[key] = value;
               return acc;
           }, {});
       }
   
       initDivider() {
           let startX = 0;
           let startLeftWidth = 0;
   
           const onMouseMove = (e) => {
               const dx = e.clientX - startX;
               const containerWidth = this.shadowRoot.host.clientWidth;
   
               let newLeftWidth = startLeftWidth + dx;
               let newRightWidth = containerWidth - newLeftWidth - 3;
   
               newLeftWidth = Math.max(this.minLeftPx, Math.min(newLeftWidth, this.maxLeftPx));
   
               newRightWidth = containerWidth - newLeftWidth - 3;
   
               if (newRightWidth < this.minRightPx) {
                   newRightWidth = this.minRightPx;
                   newLeftWidth = containerWidth - newRightWidth - 3;
               } else if (newRightWidth > this.maxRightPx) {
                   newRightWidth = this.maxRightPx;
                   newLeftWidth = containerWidth - newRightWidth - 3;
               }
   
               const leftFlex = newLeftWidth / containerWidth;
               const rightFlex = newRightWidth / containerWidth;
   
               this.leftPanel.style.flex = leftFlex.toString();
               this.rightPanel.style.flex = rightFlex.toString();
           };
   
           const onMouseUp = () => {
               document.removeEventListener("mousemove", onMouseMove);
               document.removeEventListener("mouseup", onMouseUp);
           };
   
           this.divider.addEventListener("mousedown", (e) => {
               startX = e.clientX;
               startLeftWidth = this.leftPanel.getBoundingClientRect().width;
   
               document.addEventListener("mousemove", onMouseMove);
               document.addEventListener("mouseup", onMouseUp);
           });
       }
   
       convertToPixels(value, containerWidth) {
           if (value.endsWith('%')) {
               return (parseFloat(value) / 100) * containerWidth;
           } else if (value.endsWith('px')) {
               return parseFloat(value);
           } else if (value.endsWith('em') || value.endsWith('rem')) {
               const fontSize = parseFloat(getComputedStyle(document.documentElement).fontSize) || 16;
               return parseFloat(value) * fontSize;
           } else {
               return 0;
           }
       }
   }
   
   // Define the custom element
   customElements.define('side-bar', SideBar);
  '''
--
