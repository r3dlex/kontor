import{B as w,s as S,k as $,o as r,c as s,C as P,m as g,M as B,d as p,l as C,a as o,t as d,y as T,L as D,u as b,F as V,r as z,i as h,p as N,h as j}from"./index-KpKWyOkd.js";import{u as L}from"./chat-CyyAV9gJ.js";import{_ as M}from"./_plugin-vue_export-helper-DlAUqK2U.js";var A=`
    .p-tag {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        background: dt('tag.primary.background');
        color: dt('tag.primary.color');
        font-size: dt('tag.font.size');
        font-weight: dt('tag.font.weight');
        padding: dt('tag.padding');
        border-radius: dt('tag.border.radius');
        gap: dt('tag.gap');
    }

    .p-tag-icon {
        font-size: dt('tag.icon.size');
        width: dt('tag.icon.size');
        height: dt('tag.icon.size');
    }

    .p-tag-rounded {
        border-radius: dt('tag.rounded.border.radius');
    }

    .p-tag-success {
        background: dt('tag.success.background');
        color: dt('tag.success.color');
    }

    .p-tag-info {
        background: dt('tag.info.background');
        color: dt('tag.info.color');
    }

    .p-tag-warn {
        background: dt('tag.warn.background');
        color: dt('tag.warn.color');
    }

    .p-tag-danger {
        background: dt('tag.danger.background');
        color: dt('tag.danger.color');
    }

    .p-tag-secondary {
        background: dt('tag.secondary.background');
        color: dt('tag.secondary.color');
    }

    .p-tag-contrast {
        background: dt('tag.contrast.background');
        color: dt('tag.contrast.color');
    }
`,E={root:function(e){var n=e.props;return["p-tag p-component",{"p-tag-info":n.severity==="info","p-tag-success":n.severity==="success","p-tag-warn":n.severity==="warn","p-tag-danger":n.severity==="danger","p-tag-secondary":n.severity==="secondary","p-tag-contrast":n.severity==="contrast","p-tag-rounded":n.rounded}]},icon:"p-tag-icon",label:"p-tag-label"},F=w.extend({name:"tag",style:A,classes:E}),I={name:"BaseTag",extends:S,props:{value:null,severity:null,rounded:Boolean,icon:String},style:F,provide:function(){return{$pcTag:this,$parentInstance:this}}};function u(t){"@babel/helpers - typeof";return u=typeof Symbol=="function"&&typeof Symbol.iterator=="symbol"?function(e){return typeof e}:function(e){return e&&typeof Symbol=="function"&&e.constructor===Symbol&&e!==Symbol.prototype?"symbol":typeof e},u(t)}function U(t,e,n){return(e=K(e))in t?Object.defineProperty(t,e,{value:n,enumerable:!0,configurable:!0,writable:!0}):t[e]=n,t}function K(t){var e=O(t,"string");return u(e)=="symbol"?e:e+""}function O(t,e){if(u(t)!="object"||!t)return t;var n=t[Symbol.toPrimitive];if(n!==void 0){var l=n.call(t,e);if(u(l)!="object")return l;throw new TypeError("@@toPrimitive must return a primitive value.")}return(e==="string"?String:Number)(t)}var _={name:"Tag",extends:I,inheritAttrs:!1,computed:{dataP:function(){return $(U({rounded:this.rounded},this.severity,this.severity))}}},q=["data-p"];function G(t,e,n,l,m,y){return r(),s("span",g({class:t.cx("root"),"data-p":y.dataP},t.ptmi("root")),[t.$slots.icon?(r(),P(B(t.$slots.icon),g({key:0,class:t.cx("icon")},t.ptm("icon")),null,16,["class"])):t.icon?(r(),s("span",g({key:1,class:[t.cx("icon"),t.icon]},t.ptm("icon")),null,16)):p("",!0),t.value!=null||t.$slots.default?C(t.$slots,"default",{key:2},function(){return[o("span",g({class:t.cx("label")},t.ptm("label")),d(t.value),17)]}):p("",!0)],16,q)}_.render=G;const H={class:"calendar-view"},J={class:"header"},Q={class:"date"},R={key:0,class:"loading"},W={key:1,class:"empty"},X={key:2,class:"events"},Y={class:"event-time"},Z={class:"start"},x={class:"duration"},tt={class:"event-body"},et={key:0,class:"location"},nt={class:"attendees"},at={key:0},ot={class:"event-provider"},rt={__name:"CalendarView",setup(t){const e=h([]),n=h(!0),l=L(),m=new Date().toLocaleDateString("en-US",{weekday:"long",month:"long",day:"numeric"});T(async()=>{l.setViewContext({view:"calendar",available_actions:["create_event","get_briefing"]});try{const{data:c}=await D.today();e.value=c.events}catch{}finally{n.value=!1}});function y(c){return new Date(c).toLocaleTimeString("en-US",{hour:"numeric",minute:"2-digit"})}function k(c){const i=Math.round((new Date(c.end_time)-new Date(c.start_time))/6e4);return i>=60?`${Math.floor(i/60)}h${i%60?" "+i%60+"m":""}`:`${i}m`}return(c,i)=>(r(),s("div",H,[o("div",J,[i[0]||(i[0]=o("h2",null,"Calendar",-1)),o("span",Q,d(b(m)),1)]),n.value?(r(),s("div",R,"Loading...")):e.value.length===0?(r(),s("div",W,"No events today.")):(r(),s("div",X,[(r(!0),s(V,null,z(e.value,a=>{var f,v;return r(),s("div",{key:a.id,class:"event-card"},[o("div",Y,[o("span",Z,d(y(a.start_time)),1),o("span",x,d(k(a)),1)]),o("div",tt,[o("h3",null,d(a.title),1),a.location?(r(),s("div",et,d(a.location),1)):p("",!0),o("div",nt,[N(d((f=a.attendees)==null?void 0:f.slice(0,3).join(", ")),1),((v=a.attendees)==null?void 0:v.length)>3?(r(),s("span",at," +"+d(a.attendees.length-3),1)):p("",!0)])]),o("div",ot,[j(b(_),{value:a.provider,severity:a.provider==="google"?"success":"info",class:"provider-badge"},null,8,["value","severity"])])])}),128))]))]))}},ct=M(rt,[["__scopeId","data-v-ccd55e2d"]]);export{ct as default};
