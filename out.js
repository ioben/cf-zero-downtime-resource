#!/usr/bin/env node
// deploy the app
const glob = require("glob")
const yaml = require("js-yaml")
const fs = require("fs")
const getStdin = require("get-stdin")
const cf = require("./cf")
const concourse = require("./concourse")

function validateManifest(manifest) {
  if (!manifest.applications) {
    throw new Error("Application manifest is missing the applications key")
  }
  if (manifest.applications.length !== 1) {
    throw new Error(
      `Application manifest must have one application configuration under the applications key. ${
        manifest.applications.length === 0
          ? "None exist!"
          : "Multiple are defined!"
      }`
    )
  }
  if (!manifest.applications[0]["health-check-type"]) {
    console.log(
      "WARNING: health-check-type is not defined in the manifest. Default will be used!"
    )
  }
}

/*
 * Perform variable substitutions on string `value`. Variables like `((param))`
 * will be replaced with values found in `vars` map, or in any files listed in
 * `vars_files`.
 */
function applySubstitutions(value, vars, vars_files) {
  let variables = { ...vars }
  vars_files.forEach(function (f) {
    const file_value = yaml.safeLoad(fs.readFileSync(f, "utf8"))
    variables = { ...variables, ...file_value }
  })

  let substituted_value = value;

  Object.keys(variables).forEach(k => {
    substituted_value = substituted_value.replace("((" + k + "))", variables[k])
  });

  return substituted_value
}

function validatePath(path) {
  const paths = glob.sync(path)
  if (paths.length === 0) {
    throw new Error(`Application bits cannot be found in ${path}`)
  }
  if (paths.length > 1) {
    throw new Error(
      `Expected exactly one match for ${path}, but found many : ${paths.join(
        ", "
      )}`
    )
  }

  return paths[0]
}

function editManifest({ manifest, name, env = {}, docker_username }) {
  const application = {
    ...manifest.applications[0],
    env: { ...manifest.applications[0].env, ...env }
  }

  if (typeof name !== "undefined")
    application.name = name;

  if (docker_username)
    application.docker = { ...application.docker, username: docker_username }

  return {
    ...manifest,
    applications: [application]
  }
}

async function cmd() {
  try {
    concourse.capture()
    concourse.setWorkingDirectory()

    const request = await getStdin().then(JSON.parse)

    let manifest =
      typeof request.params.manifest === "string"
        ? yaml.safeLoad(fs.readFileSync(request.params.manifest, "utf8"))
        : request.params.manifest

    validateManifest(manifest)

    const isDocker = typeof manifest.applications[0].docker !== "undefined"
    if (isDocker && request.params.path) {
      console.log(
        "WARNING: Manifest specify a docker image. path parameter will be ignored!"
      )
    }

    let path = isDocker ? null : validatePath(request.params.path)

    manifest = editManifest({
      manifest,
      name: request.params.name,
      env: request.params.environment_variables
    })

    fs.writeFileSync("manifest.yml", yaml.safeDump(manifest))

    const vars = request.params.vars || {}
    const vars_files = request.params.vars_files || []

    const app_name = applySubstitutions(manifest.applications[0].name, vars, vars_files)
    const venerable = `${app_name}-venerable`

    if (request.params.vars) {
      fs.writeFileSync("vars.yml", yaml.safeDump(request.params.vars))
      vars_files.push("vars.yml")
    }

    cf.auth(request.source)
    cf.target(request.source)

    cf.delete({ name: venerable })
    cf.rename({ from: app_name, to: venerable, failOnError: false })
    try {
      if (request.params.services) {
        cf.push({
          name: app_name,
          path: path,
          manifest: "manifest.yml",
          vars_files: vars_files,
          docker_password: request.params.docker_password,
          noStart: true
        })
        cf.bindServices({
          name: app_name,
          services: request.params.services
        })
        cf.start({ name: app_name })
      } else {
        cf.push({
          name: app_name,
          path: path,
          manifest: "manifest.yml",
          vars_files: vars_files,
          docker_password: request.params.docker_password
        })
      }
      cf.stop({ name: venerable })
    } catch (e) {
      console.error("Unable to push application to CF. Reverting...", e)
      console.log(`Recent logs for ${app_name}`)
      console.log(cf.log({ name: app_name }))
      const failed = `${app_name}-failed`
      cf.stop({ name: app_name })
      cf.delete({ name: failed })
      cf.rename({ from: app_name, to: failed })
      cf.rename({ from: venerable, to: app_name })
      console.log("Revert successful!")
      process.exit(1)
    } finally {
      if (request.params.vars) {
        fs.unlinkSync("vars.yml")
      }
    }

    const appInfo = cf.appInfo({ name: app_name, guid: request.params.guid })
    concourse.response({
      version: appInfo.metadata,
      metadata: [
        { name: "name", value: appInfo.entity.name },
        { name: "buildpack", value: appInfo.entity.buildpack },
        { name: "space", value: request.source.space },
        { name: "organization", value: request.source.organization },
        { name: "memory", value: `${appInfo.entity.memory}` },
        { name: "package_updated_at", value: appInfo.entity.package_updated_at }
      ]
    })
  } catch (e) {
    console.error(e)
    process.exit(1)
  }
}

cmd()
