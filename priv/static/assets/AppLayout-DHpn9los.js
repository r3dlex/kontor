import{w as B,o,c as p,a as t,F as C,r as A,n as T,u as i,d as w,e as V,v as z,f as M,g as N,h as d,i as y,j as I,B as L,s as U,k as j,m as k,l as E,p as v,t as _,q as H,x as R,y as K,z as D,b as O,A as b,R as h,C as q,D as F}from"./index-KpKWyOkd.js";import{u as S,S as G}from"./chat-CyyAV9gJ.js";import{u as J}from"./tasks-CaXyW6C3.js";import{s as Q}from"./index-CsckR-_Z.js";import{_ as x}from"./_plugin-vue_export-helper-DlAUqK2U.js";const W={class:"chat-panel"},X=["innerHTML"],Y={key:0,class:"message assistant"},Z={class:"chat-input"},ee=["onKeydown"],ne={__name:"ChatPanel",setup(e){const a=S(),r=y(""),u=y(null),c=y(null);async function s(){const l=r.value.trim();l&&(r.value="",await a.sendMessage(l))}function m(l){return l.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/\*\*(.*?)\*\*/g,"<strong>$1</strong>").replace(/\*(.*?)\*/g,"<em>$1</em>").replace(/`(.*?)`/g,"<code>$1</code>").replace(/\n/g,"<br>")}return B(()=>a.messages.length,async()=>{await I(),u.value&&(u.value.scrollTop=u.value.scrollHeight)}),(l,n)=>(o(),p("div",W,[n[2]||(n[2]=t("div",{class:"chat-header"},[t("span",null,"Assistant")],-1)),t("div",{class:"messages",ref_key:"messagesEl",ref:u},[(o(!0),p(C,null,A(i(a).messages,(f,g)=>(o(),p("div",{key:g,class:T(["message",f.role])},[t("div",{class:"message-content",innerHTML:m(f.content)},null,8,X)],2))),128)),i(a).isTyping?(o(),p("div",Y,[...n[1]||(n[1]=[t("div",{class:"typing-indicator"},[t("span"),t("span"),t("span")],-1)])])):w("",!0)],512),t("div",Z,[V(t("textarea",{"onUpdate:modelValue":n[0]||(n[0]=f=>r.value=f),placeholder:"Ask anything...",onKeydown:M(N(s,["exact","prevent"]),["enter"]),rows:"1",ref_key:"inputEl",ref:c},null,40,ee),[[z,r.value]]),d(i(Q),{onClick:s,disabled:!r.value.trim()||i(a).isTyping,label:"Send"},null,8,["disabled"])])]))}},te=x(ne,[["__scopeId","data-v-af2e69e1"]]);var se=`
    .p-progressbar {
        display: block;
        position: relative;
        overflow: hidden;
        height: dt('progressbar.height');
        background: dt('progressbar.background');
        border-radius: dt('progressbar.border.radius');
    }

    .p-progressbar-value {
        margin: 0;
        background: dt('progressbar.value.background');
    }

    .p-progressbar-label {
        color: dt('progressbar.label.color');
        font-size: dt('progressbar.label.font.size');
        font-weight: dt('progressbar.label.font.weight');
    }

    .p-progressbar-determinate .p-progressbar-value {
        height: 100%;
        width: 0%;
        position: absolute;
        display: none;
        display: flex;
        align-items: center;
        justify-content: center;
        overflow: hidden;
        transition: width 1s ease-in-out;
    }

    .p-progressbar-determinate .p-progressbar-label {
        display: inline-flex;
    }

    .p-progressbar-indeterminate .p-progressbar-value::before {
        content: '';
        position: absolute;
        background: inherit;
        inset-block-start: 0;
        inset-inline-start: 0;
        inset-block-end: 0;
        will-change: inset-inline-start, inset-inline-end;
        animation: p-progressbar-indeterminate-anim 2.1s cubic-bezier(0.65, 0.815, 0.735, 0.395) infinite;
    }

    .p-progressbar-indeterminate .p-progressbar-value::after {
        content: '';
        position: absolute;
        background: inherit;
        inset-block-start: 0;
        inset-inline-start: 0;
        inset-block-end: 0;
        will-change: inset-inline-start, inset-inline-end;
        animation: p-progressbar-indeterminate-anim-short 2.1s cubic-bezier(0.165, 0.84, 0.44, 1) infinite;
        animation-delay: 1.15s;
    }

    @keyframes p-progressbar-indeterminate-anim {
        0% {
            inset-inline-start: -35%;
            inset-inline-end: 100%;
        }
        60% {
            inset-inline-start: 100%;
            inset-inline-end: -90%;
        }
        100% {
            inset-inline-start: 100%;
            inset-inline-end: -90%;
        }
    }
    @-webkit-keyframes p-progressbar-indeterminate-anim {
        0% {
            inset-inline-start: -35%;
            inset-inline-end: 100%;
        }
        60% {
            inset-inline-start: 100%;
            inset-inline-end: -90%;
        }
        100% {
            inset-inline-start: 100%;
            inset-inline-end: -90%;
        }
    }

    @keyframes p-progressbar-indeterminate-anim-short {
        0% {
            inset-inline-start: -200%;
            inset-inline-end: 100%;
        }
        60% {
            inset-inline-start: 107%;
            inset-inline-end: -8%;
        }
        100% {
            inset-inline-start: 107%;
            inset-inline-end: -8%;
        }
    }
    @-webkit-keyframes p-progressbar-indeterminate-anim-short {
        0% {
            inset-inline-start: -200%;
            inset-inline-end: 100%;
        }
        60% {
            inset-inline-start: 107%;
            inset-inline-end: -8%;
        }
        100% {
            inset-inline-start: 107%;
            inset-inline-end: -8%;
        }
    }
`,ae={root:function(a){var r=a.instance;return["p-progressbar p-component",{"p-progressbar-determinate":r.determinate,"p-progressbar-indeterminate":r.indeterminate}]},value:"p-progressbar-value",label:"p-progressbar-label"},re=L.extend({name:"progressbar",style:se,classes:ae}),ie={name:"BaseProgressBar",extends:U,props:{value:{type:Number,default:null},mode:{type:String,default:"determinate"},showValue:{type:Boolean,default:!0}},style:re,provide:function(){return{$pcProgressBar:this,$parentInstance:this}}},P={name:"ProgressBar",extends:ie,inheritAttrs:!1,computed:{progressStyle:function(){return{width:this.value+"%",display:"flex"}},indeterminate:function(){return this.mode==="indeterminate"},determinate:function(){return this.mode==="determinate"},dataP:function(){return j({determinate:this.determinate,indeterminate:this.indeterminate})}}},oe=["aria-valuenow","data-p"],le=["data-p"],de=["data-p"],pe=["data-p"];function ue(e,a,r,u,c,s){return o(),p("div",k({role:"progressbar",class:e.cx("root"),"aria-valuemin":"0","aria-valuenow":e.value,"aria-valuemax":"100","data-p":s.dataP},e.ptmi("root")),[s.determinate?(o(),p("div",k({key:0,class:e.cx("value"),style:s.progressStyle,"data-p":s.dataP},e.ptm("value")),[e.value!=null&&e.value!==0&&e.showValue?(o(),p("div",k({key:0,class:e.cx("label"),"data-p":s.dataP},e.ptm("label")),[E(e.$slots,"default",{},function(){return[v(_(e.value+"%"),1)]})],16,de)):w("",!0)],16,le)):s.indeterminate?(o(),p("div",k({key:1,class:e.cx("value"),"data-p":s.dataP},e.ptm("value")),null,16,pe)):w("",!0)],16,oe)}P.render=ue;const ce={class:"import-progress"},ge={class:"progress-text"},me={__name:"ImportProgress",props:{progress:{type:Object,required:!0}},setup(e){const a=e,r=H(()=>a.progress.total>0?Math.round(a.progress.current/a.progress.total*100):0);return(u,c)=>(o(),p("div",ce,[d(i(P),{value:r.value,showValue:!1,class:"progress-bar"},null,8,["value"]),t("span",ge,"Processing "+_(e.progress.current)+" of "+_(e.progress.total),1)]))}},fe=x(me,[["__scopeId","data-v-bf4bf696"]]),ve={class:"app-layout"},be={class:"sidebar"},he={class:"nav-links"},ke={class:"main-content"},ye={class:"chat-panel"},we={__name:"AppLayout",setup(e){const a=R(),r=S(),u=J(),c=y(null);let s=null,m=null;return K(()=>{var n,f;r.connect(),s=new G("/socket",{params:{token:a.token}}),s.connect(),m=s.channel(`notifications:${(n=a.user)==null?void 0:n.id}`,{}),m.on("import_progress",({current:g,total:$})=>{c.value={current:g,total:$},g>=$&&setTimeout(()=>{c.value=null},3e3)}),m.join();const l=s.channel(`tasks:${(f=a.user)==null?void 0:f.id}`,{});l.on("task_created",({task:g})=>u.handleRealtimeUpdate(g)),l.on("task_updated",({task:g})=>u.handleRealtimeUpdate(g)),l.join()}),D(()=>{r.disconnect(),m&&m.leave(),s&&s.disconnect()}),(l,n)=>(o(),p("div",ve,[t("nav",be,[n[6]||(n[6]=O('<div class="logo" data-v-f234511a><svg width="116" height="28" viewBox="0 0 320 60" fill="none" xmlns="http://www.w3.org/2000/svg" data-v-f234511a><defs data-v-f234511a><linearGradient id="lg-sidebar" x1="0" y1="0" x2="60" y2="60" gradientUnits="userSpaceOnUse" data-v-f234511a><stop offset="0%" stop-color="#60a5fa" data-v-f234511a></stop><stop offset="100%" stop-color="#a78bfa" data-v-f234511a></stop></linearGradient></defs><text x="0" y="46" font-family="&#39;Arial Black&#39;,&#39;Helvetica Neue&#39;,Arial,sans-serif" font-size="46" font-weight="900" fill="url(#lg-sidebar)" data-v-f234511a>K</text><text x="36" y="46" font-family="&#39;Arial Black&#39;,&#39;Helvetica Neue&#39;,Arial,sans-serif" font-size="46" font-weight="900" fill="white" data-v-f234511a>ontor</text></svg></div>',1)),t("ul",he,[t("li",null,[d(i(h),{to:"/tasks"},{default:b(()=>[...n[0]||(n[0]=[v("Tasks",-1)])]),_:1})]),t("li",null,[d(i(h),{to:"/backoffice"},{default:b(()=>[...n[1]||(n[1]=[v("Back Office",-1)])]),_:1})]),t("li",null,[d(i(h),{to:"/calendar"},{default:b(()=>[...n[2]||(n[2]=[v("Calendar",-1)])]),_:1})]),t("li",null,[d(i(h),{to:"/contacts"},{default:b(()=>[...n[3]||(n[3]=[v("Contacts",-1)])]),_:1})]),t("li",null,[d(i(h),{to:"/skills"},{default:b(()=>[...n[4]||(n[4]=[v("Skills",-1)])]),_:1})]),t("li",null,[d(i(h),{to:"/settings"},{default:b(()=>[...n[5]||(n[5]=[v("Settings",-1)])]),_:1})])]),c.value?(o(),q(fe,{key:0,progress:c.value},null,8,["progress"])):w("",!0)]),t("main",ke,[d(i(F))]),t("aside",ye,[d(te)])]))}},Be=x(we,[["__scopeId","data-v-f234511a"]]);export{Be as default};
