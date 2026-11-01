<template>
  <!-- 原版该页只有一句「用户注册页，请自行实现」占位，这里按后端校验规则补齐 -->
  <div id="userRegisterView">
    <h2 style="margin-bottom: 16px">用户注册</h2>
    <a-form
      style="max-width: 480px; margin: 0 auto"
      label-align="left"
      auto-label-width
      :model="form"
      @submit="handleSubmit"
    >
      <a-form-item field="userAccount" label="账号">
        <a-input v-model="form.userAccount" placeholder="账号不少于 4 位" />
      </a-form-item>
      <a-form-item field="userPassword" tooltip="密码不少于 8 位" label="密码">
        <a-input-password
          v-model="form.userPassword"
          placeholder="请输入密码"
        />
      </a-form-item>
      <a-form-item
        field="checkPassword"
        tooltip="须与密码一致"
        label="确认密码"
      >
        <a-input-password
          v-model="form.checkPassword"
          placeholder="请再次输入密码"
        />
      </a-form-item>
      <a-form-item>
        <a-space>
          <a-button type="primary" html-type="submit" style="width: 120px">
            注册
          </a-button>
          <a-link @click="toLogin">已有账号？去登录</a-link>
        </a-space>
      </a-form-item>
    </a-form>
  </div>
</template>

<script setup lang="ts">
import { reactive } from "vue";
import { UserControllerService, UserRegisterRequest } from "../../../generated";
import message from "@arco-design/web-vue/es/message";
import { useRouter } from "vue-router";

/**
 * 表单信息
 */
const form = reactive({
  userAccount: "",
  userPassword: "",
  checkPassword: "",
} as UserRegisterRequest);

const router = useRouter();

/**
 * 提交表单
 */
const handleSubmit = async () => {
  // 前端先做一遍和后端一致的校验，避免无谓请求
  if (!form.userAccount || form.userAccount.length < 4) {
    message.error("账号不少于 4 位");
    return;
  }
  if (!form.userPassword || form.userPassword.length < 8) {
    message.error("密码不少于 8 位");
    return;
  }
  if (form.userPassword !== form.checkPassword) {
    message.error("两次输入的密码不一致");
    return;
  }
  const res = await UserControllerService.userRegisterUsingPost(form);
  if (res.code === 0) {
    message.success("注册成功，请登录");
    router.push({
      path: "/user/login",
      replace: true,
    });
  } else {
    message.error("注册失败，" + res.message);
  }
};

const toLogin = () => {
  router.push({
    path: "/user/login",
  });
};
</script>
