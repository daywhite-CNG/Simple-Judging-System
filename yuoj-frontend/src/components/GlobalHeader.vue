<template>
  <a-row id="globalHeader" align="center" :wrap="false">
    <a-col flex="auto">
      <a-menu
        mode="horizontal"
        :selected-keys="selectedKeys"
        @menu-item-click="doMenuClick"
      >
        <a-menu-item
          key="0"
          :style="{ padding: 0, marginRight: '38px' }"
          disabled
        >
          <div class="title-bar">
            <img class="logo" src="../assets/oj-logo.svg" />
            <div class="title">鱼 OJ</div>
          </div>
        </a-menu-item>
        <a-menu-item v-for="item in visibleRoutes" :key="item.path">
          {{ item.name }}
        </a-menu-item>
      </a-menu>
    </a-col>
    <a-col flex="140px">
      <div class="account-bar">
        <template v-if="isLoggedIn">
          <a-tag color="arcoblue">{{ displayName }}</a-tag>
        </template>
        <template v-else>
          <a-link @click="toLogin">登录</a-link>
          <a-divider direction="vertical" />
          <a-link @click="toRegister">注册</a-link>
        </template>
      </div>
    </a-col>
  </a-row>
</template>

<script setup lang="ts">
import { routes } from "../router/routes";
import { useRoute, useRouter } from "vue-router";
import { computed, ref } from "vue";
import { useStore } from "vuex";
import checkAccess from "@/access/checkAccess";
import ACCESS_ENUM from "@/access/accessEnum";

const router = useRouter();
const store = useStore();

// 展示在菜单的路由数组
const visibleRoutes = computed(() => {
  return routes.filter((item, index) => {
    if (item.meta?.hideInMenu) {
      return false;
    }
    // 根据权限过滤菜单
    if (
      !checkAccess(store.state.user.loginUser, item?.meta?.access as string)
    ) {
      return false;
    }
    return true;
  });
});

// 默认主页
const selectedKeys = ref(["/"]);

// 路由跳转后，更新选中的菜单项
router.afterEach((to, from, failure) => {
  selectedKeys.value = [to.path];
});

// 是否已登录：初始 state 没有 userRole，视为未登录
const isLoggedIn = computed(() => {
  const user = store.state.user?.loginUser;
  return !!user?.userRole && user.userRole !== ACCESS_ENUM.NOT_LOGIN;
});

// 注册时未填昵称的话 userName 为 null，回退显示账号
const displayName = computed(() => {
  const user = store.state.user?.loginUser;
  return user?.userName || user?.userAccount || "已登录";
});

const toLogin = () => {
  router.push({ path: "/user/login" });
};

const toRegister = () => {
  router.push({ path: "/user/register" });
};

const doMenuClick = (key: string) => {
  router.push({
    path: key,
  });
};
</script>

<style scoped>
.title-bar {
  display: flex;
  align-items: center;
}

.title {
  color: #444;
  margin-left: 16px;
}

.logo {
  height: 48px;
}

.account-bar {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 4px;
}
</style>
