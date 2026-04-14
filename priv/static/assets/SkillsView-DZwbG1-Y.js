import{B as U,k as M,m as A,o as i,c as o,y as q,O as y,a as n,F as R,r as L,t as p,d as f,n as C,h as w,u as z,i as u,g as K}from"./index-KpKWyOkd.js";import{u as G}from"./chat-CyyAV9gJ.js";import{s as T}from"./index-CsckR-_Z.js";import{s as J}from"./index-BMk84Fib.js";import{_ as Q}from"./_plugin-vue_export-helper-DlAUqK2U.js";var W=`
    .p-textarea {
        font-family: inherit;
        font-feature-settings: inherit;
        font-size: 1rem;
        color: dt('textarea.color');
        background: dt('textarea.background');
        padding-block: dt('textarea.padding.y');
        padding-inline: dt('textarea.padding.x');
        border: 1px solid dt('textarea.border.color');
        transition:
            background dt('textarea.transition.duration'),
            color dt('textarea.transition.duration'),
            border-color dt('textarea.transition.duration'),
            outline-color dt('textarea.transition.duration'),
            box-shadow dt('textarea.transition.duration');
        appearance: none;
        border-radius: dt('textarea.border.radius');
        outline-color: transparent;
        box-shadow: dt('textarea.shadow');
    }

    .p-textarea:enabled:hover {
        border-color: dt('textarea.hover.border.color');
    }

    .p-textarea:enabled:focus {
        border-color: dt('textarea.focus.border.color');
        box-shadow: dt('textarea.focus.ring.shadow');
        outline: dt('textarea.focus.ring.width') dt('textarea.focus.ring.style') dt('textarea.focus.ring.color');
        outline-offset: dt('textarea.focus.ring.offset');
    }

    .p-textarea.p-invalid {
        border-color: dt('textarea.invalid.border.color');
    }

    .p-textarea.p-variant-filled {
        background: dt('textarea.filled.background');
    }

    .p-textarea.p-variant-filled:enabled:hover {
        background: dt('textarea.filled.hover.background');
    }

    .p-textarea.p-variant-filled:enabled:focus {
        background: dt('textarea.filled.focus.background');
    }

    .p-textarea:disabled {
        opacity: 1;
        background: dt('textarea.disabled.background');
        color: dt('textarea.disabled.color');
    }

    .p-textarea::placeholder {
        color: dt('textarea.placeholder.color');
    }

    .p-textarea.p-invalid::placeholder {
        color: dt('textarea.invalid.placeholder.color');
    }

    .p-textarea-fluid {
        width: 100%;
    }

    .p-textarea-resizable {
        overflow: hidden;
        resize: none;
    }

    .p-textarea-sm {
        font-size: dt('textarea.sm.font.size');
        padding-block: dt('textarea.sm.padding.y');
        padding-inline: dt('textarea.sm.padding.x');
    }

    .p-textarea-lg {
        font-size: dt('textarea.lg.font.size');
        padding-block: dt('textarea.lg.padding.y');
        padding-inline: dt('textarea.lg.padding.x');
    }
`,X={root:function(e){var d=e.instance,v=e.props;return["p-textarea p-component",{"p-filled":d.$filled,"p-textarea-resizable ":v.autoResize,"p-textarea-sm p-inputfield-sm":v.size==="small","p-textarea-lg p-inputfield-lg":v.size==="large","p-invalid":d.$invalid,"p-variant-filled":d.$variant==="filled","p-textarea-fluid":d.$fluid}]}},Y=U.extend({name:"textarea",style:W,classes:X}),Z={name:"BaseTextarea",extends:J,props:{autoResize:Boolean},style:Y,provide:function(){return{$pcTextarea:this,$parentInstance:this}}};function $(a){"@babel/helpers - typeof";return $=typeof Symbol=="function"&&typeof Symbol.iterator=="symbol"?function(e){return typeof e}:function(e){return e&&typeof Symbol=="function"&&e.constructor===Symbol&&e!==Symbol.prototype?"symbol":typeof e},$(a)}function ee(a,e,d){return(e=te(e))in a?Object.defineProperty(a,e,{value:d,enumerable:!0,configurable:!0,writable:!0}):a[e]=d,a}function te(a){var e=ae(a,"string");return $(e)=="symbol"?e:e+""}function ae(a,e){if($(a)!="object"||!a)return a;var d=a[Symbol.toPrimitive];if(d!==void 0){var v=d.call(a,e);if($(v)!="object")return v;throw new TypeError("@@toPrimitive must return a primitive value.")}return(e==="string"?String:Number)(a)}var B={name:"Textarea",extends:Z,inheritAttrs:!1,observer:null,mounted:function(){var e=this;this.autoResize&&(this.observer=new ResizeObserver(function(){requestAnimationFrame(function(){e.resize()})}),this.observer.observe(this.$el))},updated:function(){this.autoResize&&this.resize()},beforeUnmount:function(){this.observer&&this.observer.disconnect()},methods:{resize:function(){if(this.$el.offsetParent){var e=this.$el.style.height,d=parseInt(e)||0,v=this.$el.scrollHeight,l=!d||v>d,c=d&&v<d;c?(this.$el.style.height="auto",this.$el.style.height="".concat(this.$el.scrollHeight,"px")):l&&(this.$el.style.height="".concat(v,"px"))}},onInput:function(e){this.autoResize&&this.resize(),this.writeValue(e.target.value,e)}},computed:{attrs:function(){return A(this.ptmi("root",{context:{filled:this.$filled,disabled:this.disabled}}),this.formField)},dataP:function(){return M(ee({invalid:this.$invalid,fluid:this.$fluid,filled:this.$variant==="filled"},this.size,this.size))}}},ne=["value","name","disabled","aria-invalid","data-p"];function se(a,e,d,v,l,c){return i(),o("textarea",A({class:a.cx("root"),value:a.d_value,name:a.name,disabled:a.disabled,"aria-invalid":a.invalid||void 0,"data-p":c.dataP,onInput:e[0]||(e[0]=function(){return c.onInput&&c.onInput.apply(c,arguments)})},c.attrs),null,16,ne)}B.render=se;const ie={class:"skills-view"},oe={key:0,class:"loading"},le={key:1,class:"skills-layout"},re={class:"skills-list"},de=["onClick"],ce={class:"skill-header"},ue={class:"skill-name"},ve={class:"skill-badges"},pe={key:0,class:"badge locked"},fe={key:1,class:"badge inactive"},he={class:"badge namespace"},be={class:"skill-meta"},ye={key:0,class:"skill-editor"},ge={class:"editor-header"},me={class:"editor-title"},_e={class:"editor-skill-name"},xe={class:"editor-badges"},ke={key:0,class:"badge locked"},we={key:1,class:"badge inactive"},ze={class:"badge namespace"},$e={class:"editor-meta"},Se={class:"editor-tabs"},Ve={key:0,class:"tab-pane"},Ce={key:0,class:"loading"},Ie={class:"editor-actions"},Pe={key:0,class:"save-error"},Re={key:1,class:"save-success"},Te={key:1,class:"tab-pane"},Be={key:0,class:"loading"},Le={key:1,class:"empty"},Ae={key:2,class:"versions-layout"},Ee={class:"versions-list"},He=["onClick"],Ne={class:"version-number"},De={class:"version-meta"},Fe={key:0,class:"version-preview"},je={class:"editor-actions"},Oe={key:0,class:"save-error"},Ue={key:1,class:"editor-empty"},Me={__name:"SkillsView",setup(a){const e=u([]),d=u(!0),v=G(),l=u(null),c=u("content"),g=u(""),I=u(!1),S=u(!1),m=u(""),_=u(!1),x=u([]),P=u(!1),h=u(null),V=u(!1),k=u("");q(async()=>{v.setViewContext({view:"skill_editor",available_actions:["list_skills","trigger_skill"]});try{const{data:r}=await y.list();e.value=r.skills}finally{d.value=!1}});async function E(r){const{data:s}=await y.update(r.id,{active:!r.active}),t=e.value.findIndex(b=>b.id===r.id);t!==-1&&(e.value[t]=s.skill,l.value&&l.value.id===r.id&&(l.value=s.skill))}async function H(r){l.value=r,c.value="content",m.value="",_.value=!1,x.value=[],h.value=null,I.value=!0;try{const{data:s}=await y.get(r.id);g.value=s.skill.content||""}finally{I.value=!1}}async function N(){S.value=!0,m.value="",_.value=!1;try{const{data:r}=await y.update(l.value.id,{content:g.value}),s=e.value.findIndex(t=>t.id===l.value.id);s!==-1&&(e.value[s]=r.skill),l.value=r.skill,_.value=!0,setTimeout(()=>{_.value=!1},2e3)}catch{m.value="Save failed. Please try again."}finally{S.value=!1}}async function D(){if(c.value="versions",!(x.value.length>0)){P.value=!0;try{const{data:r}=await y.getVersions(l.value.id);x.value=r.versions}finally{P.value=!1}}}function F(r){h.value=r,k.value=""}async function j(r){V.value=!0,k.value="";try{const{data:s}=await y.revertVersion(l.value.id,r.id),t=e.value.findIndex(b=>b.id===l.value.id);t!==-1&&(e.value[t]=s.skill),l.value=s.skill,g.value=s.skill.content||"",c.value="content"}catch{k.value="Revert failed. Please try again."}finally{V.value=!1}}function O(r){return r?new Date(r).toLocaleString():""}return(r,s)=>(i(),o("div",ie,[s[6]||(s[6]=n("div",{class:"header"},[n("h2",null,"Skills")],-1)),d.value?(i(),o("div",oe,"Loading...")):(i(),o("div",le,[n("div",re,[(i(!0),o(R,null,L(e.value,t=>(i(),o("div",{key:t.id,class:C(["skill-card",{selected:l.value&&l.value.id===t.id}]),onClick:b=>H(t)},[n("div",ce,[n("div",ue,p(t.name),1),n("div",ve,[t.locked?(i(),o("span",pe,"Locked")):f("",!0),t.active?f("",!0):(i(),o("span",fe,"Inactive")),n("span",he,p(t.namespace),1)])]),n("div",be,[n("span",null,"v"+p(t.version),1),s[4]||(s[4]=n("span",null,"·",-1)),n("span",null,p(t.author),1)]),n("div",{class:"skill-actions",onClick:s[0]||(s[0]=K(()=>{},["stop"]))},[w(z(T),{onClick:b=>E(t),label:t.active?"Deactivate":"Activate",size:"small",severity:t.active?"secondary":"success",text:""},null,8,["onClick","label","severity"])])],10,de))),128))]),l.value?(i(),o("div",ye,[n("div",ge,[n("div",me,[n("span",_e,p(l.value.name),1),n("div",xe,[l.value.locked?(i(),o("span",ke,"Locked")):f("",!0),l.value.active?f("",!0):(i(),o("span",we,"Inactive")),n("span",ze,p(l.value.namespace),1)])]),n("div",$e,"v"+p(l.value.version)+" · "+p(l.value.author),1)]),n("div",Se,[n("button",{class:C(["tab-btn",{active:c.value==="content"}]),onClick:s[1]||(s[1]=t=>c.value="content")},"Content",2),n("button",{class:C(["tab-btn",{active:c.value==="versions"}]),onClick:D},"Versions",2)]),c.value==="content"?(i(),o("div",Ve,[I.value?(i(),o("div",Ce,"Loading content...")):(i(),o(R,{key:1},[w(z(B),{class:"content-textarea",rows:"20",modelValue:g.value,"onUpdate:modelValue":s[2]||(s[2]=t=>g.value=t),autoResize:""},null,8,["modelValue"]),n("div",Ie,[w(z(T),{class:"btn-save",disabled:S.value,onClick:N,label:S.value?"Saving...":"Save"},null,8,["disabled","label"]),m.value?(i(),o("span",Pe,p(m.value),1)):f("",!0),_.value?(i(),o("span",Re,"Saved.")):f("",!0)])],64))])):f("",!0),c.value==="versions"?(i(),o("div",Te,[P.value?(i(),o("div",Be,"Loading versions...")):x.value.length===0?(i(),o("div",Le,"No version history yet.")):(i(),o("div",Ae,[n("div",Ee,[(i(!0),o(R,null,L(x.value,t=>(i(),o("div",{key:t.id,class:C(["version-item",{selected:h.value&&h.value.id===t.id}]),onClick:b=>F(t)},[n("div",Ne,"v"+p(t.version),1),n("div",De,[n("span",null,p(t.author),1),n("span",null,p(O(t.updated_at||t.inserted_at)),1)])],10,He))),128))]),h.value?(i(),o("div",Fe,[w(z(B),{class:"content-textarea readonly",rows:"16",readonly:"",modelValue:h.value.content,autoResize:""},null,8,["modelValue"]),n("div",je,[w(z(T),{class:"btn-save",disabled:V.value,onClick:s[3]||(s[3]=t=>j(h.value)),label:V.value?"Reverting...":"Revert to this version"},null,8,["disabled","label"]),k.value?(i(),o("span",Oe,p(k.value),1)):f("",!0)])])):f("",!0)]))])):f("",!0)])):(i(),o("div",Ue,[...s[5]||(s[5]=[n("span",null,"Select a skill to edit",-1)])]))]))]))}},We=Q(Me,[["__scopeId","data-v-0753a961"]]);export{We as default};
